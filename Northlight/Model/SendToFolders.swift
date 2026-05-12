import Foundation

struct SendToFolder: Codable, Sendable, Equatable {
    let path: String

    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
    var displayName: String { (path as NSString).lastPathComponent }
}

enum SendToFolders {
    private static let key = "sendTo.folders.v3"

    static var all: [SendToFolder] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([SendToFolder].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    static func add(folder: SendToFolder) {
        var current = all
        if !current.contains(where: { $0.path == folder.path }) {
            current.append(folder)
            all = current
        }
    }

    static func remove(at index: Int) {
        var current = all
        guard current.indices.contains(index) else { return }
        current.remove(at: index)
        all = current
    }
}
