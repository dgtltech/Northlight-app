import Foundation
import UniformTypeIdentifiers

struct FormatHandler: Sendable {
    let title: String
    let extensions: [String]
    let typeIdentifier: String

    var utType: UTType? {
        UTType(typeIdentifier)
    }

    var extensionsDisplay: String {
        extensions.map { "." + $0 }.joined(separator: " · ")
    }
}

enum FileFormatRegistry {
    static let formats: [FormatHandler] = [
        FormatHandler(title: "JPEG", extensions: ["jpg", "jpeg"], typeIdentifier: "public.jpeg"),
        FormatHandler(title: "PNG", extensions: ["png"], typeIdentifier: "public.png"),
        FormatHandler(title: "GIF", extensions: ["gif"], typeIdentifier: "com.compuserve.gif"),
        FormatHandler(title: "TIFF", extensions: ["tiff", "tif"], typeIdentifier: "public.tiff"),
        FormatHandler(title: "BMP", extensions: ["bmp"], typeIdentifier: "com.microsoft.bmp"),
        FormatHandler(title: "ICO", extensions: ["ico"], typeIdentifier: "com.microsoft.ico"),
        FormatHandler(title: "ICNS", extensions: ["icns"], typeIdentifier: "com.apple.icns"),
        FormatHandler(title: "HEIC", extensions: ["heic"], typeIdentifier: "public.heic"),
        FormatHandler(title: "HEIF", extensions: ["heif"], typeIdentifier: "public.heif"),
        FormatHandler(title: "WebP", extensions: ["webp"], typeIdentifier: "org.webmproject.webp"),
        FormatHandler(title: "AVIF", extensions: ["avif"], typeIdentifier: "public.avif"),
        FormatHandler(title: "JPEG XL", extensions: ["jxl"], typeIdentifier: "public.jpeg-xl"),
        FormatHandler(title: "SVG", extensions: ["svg", "svgz"], typeIdentifier: "public.svg-image"),
        FormatHandler(title: "PSD", extensions: ["psd"], typeIdentifier: "com.adobe.photoshop-image"),
        FormatHandler(title: "RAW (generic)", extensions: ["raw"], typeIdentifier: "public.camera-raw-image"),
        FormatHandler(title: "Canon CR2", extensions: ["cr2"], typeIdentifier: "com.canon.cr2-raw-image"),
        FormatHandler(title: "Canon CR3", extensions: ["cr3"], typeIdentifier: "com.canon.cr3-raw-image"),
        FormatHandler(title: "Canon CRW", extensions: ["crw"], typeIdentifier: "com.canon.crw-raw-image"),
        FormatHandler(title: "Nikon NEF", extensions: ["nef"], typeIdentifier: "com.nikon.raw-image"),
        FormatHandler(title: "Nikon NRW", extensions: ["nrw"], typeIdentifier: "com.nikon.nrw-raw-image"),
        FormatHandler(title: "Sony ARW", extensions: ["arw"], typeIdentifier: "com.sony.arw-raw-image"),
        FormatHandler(title: "Adobe DNG", extensions: ["dng"], typeIdentifier: "com.adobe.raw-image"),
        FormatHandler(title: "Fujifilm RAF", extensions: ["raf"], typeIdentifier: "com.fuji.raw-image"),
        FormatHandler(title: "Panasonic RW2", extensions: ["rw2"], typeIdentifier: "com.panasonic.rw2-raw-image"),
        FormatHandler(title: "Olympus ORF", extensions: ["orf"], typeIdentifier: "com.olympus.or-raw-image"),
        FormatHandler(title: "Pentax PEF", extensions: ["pef"], typeIdentifier: "com.pentax.raw-image"),
        FormatHandler(title: "Sigma X3F", extensions: ["x3f"], typeIdentifier: "com.sigma.x3f-raw-image"),
        FormatHandler(title: "Hasselblad 3FR", extensions: ["3fr"], typeIdentifier: "com.hasselblad.3fr-raw-image"),
        FormatHandler(title: "Mamiya MEF", extensions: ["mef"], typeIdentifier: "com.mamiya.raw-image"),
        FormatHandler(title: "Phase One IIQ", extensions: ["iiq"], typeIdentifier: "com.phaseone.raw-image"),
        FormatHandler(title: "Leica RWL", extensions: ["rwl"], typeIdentifier: "com.leica.raw-image"),
        FormatHandler(title: "Kodak", extensions: ["kdc", "dcr"], typeIdentifier: "com.kodak.raw-image"),
        FormatHandler(title: "Minolta MRW", extensions: ["mrw"], typeIdentifier: "com.minolta.raw-image"),
        FormatHandler(title: "Epson ERF", extensions: ["erf"], typeIdentifier: "com.epson.raw-image")
    ]
}
