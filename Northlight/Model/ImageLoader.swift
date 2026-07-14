import AppKit
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImageLoadError: Error {
    case cannotReadFile
    case cannotCreateSource
    case emptySource
    case cannotReadDimensions
}

struct LoadedImage: @unchecked Sendable {
    let data: Data
    let pixelSize: CGSize
    let frameCount: Int
    let formatUTI: String?
    let rendersViaWebKit: Bool
}

enum ImageLoader {
    static func load(url: URL) async throws -> LoadedImage {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()

            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw ImageLoadError.cannotReadFile
            }

            try Task.checkCancellation()

            // SVG is not decodable by ImageIO; NSImage renders it via CoreSVG.
            let ext = url.pathExtension.lowercased()
            if ext == "svg" || ext == "svgz" {
                return try loadSVG(data: data)
            }

            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                throw ImageLoadError.cannotCreateSource
            }
            let count = CGImageSourceGetCount(source)
            guard count > 0 else {
                throw ImageLoadError.emptySource
            }

            try Task.checkCancellation()

            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let widthValue = (props?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
            let heightValue = (props?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
            guard widthValue > 0, heightValue > 0 else {
                throw ImageLoadError.cannotReadDimensions
            }

            // kCGImagePropertyPixelWidth/Height report the raw decoded buffer and ignore
            // EXIF orientation, but NSImage(data:) bakes orientation into the bitmap rep.
            // For orientations 5–8 (90°/270° rotations) display width and height are swapped,
            // so swap them here to keep pixelSize aligned with what gets rendered. Otherwise
            // fit-to-window math, the status bar, and the size override below all use the
            // wrong (landscape) dimensions for portrait photos and vice versa.
            let orientation = (props?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
            let swapsDimensions = (5...8).contains(orientation)
            let displaySize = swapsDimensions
                ? CGSize(width: heightValue, height: widthValue)
                : CGSize(width: widthValue, height: heightValue)

            let formatUTI = CGImageSourceGetType(source) as String?

            return LoadedImage(
                data: data,
                pixelSize: displaySize,
                frameCount: count,
                formatUTI: formatUTI,
                rendersViaWebKit: false
            )
        }.value
    }

    private static func loadSVG(data: Data) throws -> LoadedImage {
        // Sniff the gzip magic instead of trusting the extension, so a
        // compressed file named .svg still opens.
        var svgData = data
        let wasCompressed = data.count >= 2 && data[0] == 0x1f && data[1] == 0x8b
        if wasCompressed {
            guard let inflated = gunzip(data) else {
                throw ImageLoadError.cannotCreateSource
            }
            svgData = inflated
        }

        // Probe with NSImage so the loader stays the single source of truth for
        // dimensions; CoreSVG resolves the intrinsic size from width/height or
        // viewBox. LoadedImage carries the decompressed bytes so the display
        // path's NSImage(data:) works for .svgz unchanged.
        guard let image = NSImage(data: svgData) else {
            throw ImageLoadError.cannotCreateSource
        }
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            throw ImageLoadError.cannotReadDimensions
        }

        // WebKit renders from the file URL, which cannot serve gzip-compressed
        // documents — compressed files stay on the CoreSVG path.
        return LoadedImage(
            data: svgData,
            pixelSize: size,
            frameCount: 1,
            formatUTI: UTType.svg.identifier,
            rendersViaWebKit: !wasCompressed && needsWebRendering(svgData)
        )
    }

    // CoreSVG cannot draw these constructs (verified empirically): <image>
    // never loads its resource, <filter> effects are skipped, fill on <tspan>
    // is ignored, stylesheets and scripts are not applied. Such files render
    // through WKWebView instead. A false positive is harmless — WebKit draws
    // simple SVGs correctly too, only losing background transparency.
    private static func needsWebRendering(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8)?.lowercased() else { return false }
        if text.contains("<image") || text.contains("<filter") || text.contains("<style")
            || text.contains("<script") || text.contains("<foreignobject") {
            return true
        }
        return text.range(of: "<tspan[^>]*(fill|style)\\s*=", options: .regularExpression) != nil
    }

    // Minimal gzip container parsing (RFC 1952): validate the header, skip the
    // optional fields, drop the 8-byte CRC/size trailer, then inflate the raw
    // DEFLATE stream. NSData's .zlib algorithm expects exactly that stream —
    // it does not accept the gzip container itself.
    private static func gunzip(_ data: Data) -> Data? {
        guard data.count > 18, data[0] == 0x1f, data[1] == 0x8b, data[2] == 8 else { return nil }
        let flags = data[3]
        var index = 10
        if flags & 0x04 != 0 {  // FEXTRA
            guard index + 2 <= data.count else { return nil }
            let extraLength = Int(data[index]) | Int(data[index + 1]) << 8
            index += 2 + extraLength
        }
        if flags & 0x08 != 0 {  // FNAME
            while index < data.count, data[index] != 0 { index += 1 }
            index += 1
        }
        if flags & 0x10 != 0 {  // FCOMMENT
            while index < data.count, data[index] != 0 { index += 1 }
            index += 1
        }
        if flags & 0x02 != 0 {  // FHCRC
            index += 2
        }
        guard index < data.count - 8 else { return nil }
        let deflated = data.subdata(in: index..<(data.count - 8))
        return (try? (deflated as NSData).decompressed(using: .zlib)) as Data?
    }
}
