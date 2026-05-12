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

            let formatUTI = CGImageSourceGetType(source) as String?

            return LoadedImage(
                data: data,
                pixelSize: CGSize(width: widthValue, height: heightValue),
                frameCount: count,
                formatUTI: formatUTI
            )
        }.value
    }
}
