import Foundation

enum SortOrder: String, CaseIterable, Sendable {
    case name
    case dateModified
    case dateCreated
    case dateAdded
    case fileSize
}

enum SortPreferences {
    private static let orderKey = "sort.order"
    private static let reversedKey = "sort.reversed"

    static var order: SortOrder {
        get {
            guard let raw = UserDefaults.standard.string(forKey: orderKey),
                  let value = SortOrder(rawValue: raw) else {
                return .name
            }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: orderKey) }
    }

    static var isReversed: Bool {
        get { UserDefaults.standard.bool(forKey: reversedKey) }
        set { UserDefaults.standard.set(newValue, forKey: reversedKey) }
    }
}
