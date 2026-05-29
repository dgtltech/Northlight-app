import Foundation
import CoreGraphics
import ImageIO

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
                formatUTI: formatUTI
            )
        }.value
    }
}
