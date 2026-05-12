import AppKit

struct IconPreset: Sendable {
    let key: String
    let displayName: String
    let assetName: String?
}

@MainActor
enum AppIconManager {
    private static let selectionKey = "icon.selectedKey"

    static let presets: [IconPreset] = [
        IconPreset(key: "default", displayName: "Default", assetName: nil),
        IconPreset(key: "aurora", displayName: "Compass", assetName: "AltIconAurora"),
        IconPreset(key: "duck", displayName: "Duck", assetName: "AltIconDuck"),
        IconPreset(key: "n3", displayName: "Aurora", assetName: "AltIconN3")
    ]

    static var selectedKey: String {
        let stored = UserDefaults.standard.string(forKey: selectionKey) ?? "default"
        if presets.contains(where: { $0.key == stored }) {
            return stored
        }
        return "default"
    }

    static func image(for preset: IconPreset) -> NSImage {
        if let assetName = preset.assetName, let img = NSImage(named: assetName) {
            return img
        }
        return NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    static var currentImage: NSImage {
        let key = selectedKey
        if let preset = presets.first(where: { $0.key == key }) {
            return image(for: preset)
        }
        return NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    static func applyOnLaunch() {
        let image = currentImage
        if image.size.width > 0 {
            NSApp.applicationIconImage = image
        }
    }

    static func selectPreset(_ preset: IconPreset) {
        UserDefaults.standard.set(preset.key, forKey: selectionKey)
        NSApp.applicationIconImage = image(for: preset)
    }

    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: selectionKey)
        if let bundleIcon = NSImage(named: NSImage.applicationIconName) {
            NSApp.applicationIconImage = bundleIcon
        }
    }
}
