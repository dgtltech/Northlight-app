import AppKit

enum BackgroundMode: String, CaseIterable, Sendable {
    case themeDefault
    case themeOpposite
    case pink
    case green
    case white
    case black

    var displayColor: NSColor {
        switch self {
        case .themeDefault: return NSColor(white: 0.18, alpha: 1.0)
        case .themeOpposite: return NSColor(white: 0.82, alpha: 1.0)
        case .pink: return NSColor(red: 1.00, green: 0.78, blue: 0.88, alpha: 1.0)
        case .green: return NSColor(red: 0.78, green: 1.00, blue: 0.80, alpha: 1.0)
        case .white: return .white
        case .black: return .black
        }
    }

    var next: BackgroundMode {
        let all = BackgroundMode.allCases
        guard let idx = all.firstIndex(of: self) else { return .themeDefault }
        return all[(idx + 1) % all.count]
    }
}

@MainActor
enum BackgroundPreferences {
    private static let key = "background.mode"
    static let didChangeNotification = Notification.Name("BackgroundPreferences.didChange")

    static var mode: BackgroundMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let value = BackgroundMode(rawValue: raw) else {
                return .themeDefault
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    static func cycle() {
        mode = mode.next
    }
}
