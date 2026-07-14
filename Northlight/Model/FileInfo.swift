import Foundation

struct FileInfo: Sendable {
    let url: URL
    let fileSize: Int64
    let modificationDate: Date?

    static func load(from url: URL) -> FileInfo {
        var size: Int64 = 0
        var modDate: Date? = nil
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)) {
            size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            modDate = attrs[.modificationDate] as? Date
        }
        return FileInfo(url: url, fileSize: size, modificationDate: modDate)
    }
}

enum FileFormatName {
    static func display(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "jpe", "jfif": return "JPEG"
        case "tif", "tiff": return "TIFF"
        case "heic", "heif", "heics": return "HEIC"
        case "avif", "avifs": return "AVIF"
        case "jxl": return "JPEG XL"
        case "svg", "svgz": return "SVG"
        case "png": return "PNG"
        case "webp": return "WebP"
        case "gif": return "GIF"
        case "bmp": return "BMP"
        case "psd": return "PSD"
        default: return ext.uppercased()
        }
    }
}
