import Foundation

enum SupportedFormats {
    static let extensions: Set<String> = [
        "jpg", "jpeg", "jpe", "jfif",
        "png",
        "gif",
        "tiff", "tif",
        "bmp",
        "ico",
        "icns",
        "heic", "heif", "heics",
        "webp",
        "avif", "avifs",
        "jxl",
        "psd",
        "cr2", "cr3", "crw",
        "nef", "nrw",
        "arw", "srf", "sr2",
        "dng",
        "raf",
        "rw2",
        "orf",
        "pef", "ptx",
        "x3f",
        "raw", "rwl",
        "kdc", "dcr",
        "mrw",
        "3fr",
        "erf",
        "mef",
        "mos",
        "iiq"
    ]

    static func isSupported(url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }
}
