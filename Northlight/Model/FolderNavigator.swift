import Foundation

final class FolderNavigator {

    struct Entry: Sendable {
        let url: URL
        let dateModified: Date?
        let dateCreated: Date?
        let dateAdded: Date?
        let fileSize: Int64
    }

    let folder: URL
    private(set) var entries: [Entry]
    private(set) var currentIndex: Int
    private(set) var sortOrder: SortOrder
    private(set) var isReversed: Bool

    var isEmpty: Bool { entries.isEmpty }
    var count: Int { entries.count }

    var currentURL: URL? {
        entries.indices.contains(currentIndex) ? entries[currentIndex].url : nil
    }

    var currentPosition: (index: Int, total: Int)? {
        guard !entries.isEmpty, entries.indices.contains(currentIndex) else { return nil }
        return (currentIndex + 1, entries.count)
    }

    init(folder: URL, entries: [Entry], currentURL: URL, sortOrder: SortOrder, isReversed: Bool) {
        self.folder = folder
        self.sortOrder = sortOrder
        self.isReversed = isReversed

        var allEntries = entries
        if !entries.contains(where: { Self.sameFile($0.url, currentURL) }) {
            allEntries.append(Self.makeEntry(url: currentURL))
        }
        let sorted = Self.sort(allEntries, by: sortOrder, reversed: isReversed)
        self.entries = sorted
        self.currentIndex = sorted.firstIndex { Self.sameFile($0.url, currentURL) } ?? 0
    }

    func setCurrent(url: URL) {
        if let idx = entries.firstIndex(where: { Self.sameFile($0.url, url) }) {
            currentIndex = idx
        }
    }

    func renameEntry(from oldURL: URL, to newURL: URL) {
        guard let idx = entries.firstIndex(where: { Self.sameFile($0.url, oldURL) }) else { return }
        let old = entries[idx]
        entries[idx] = Entry(
            url: newURL,
            dateModified: old.dateModified,
            dateCreated: old.dateCreated,
            dateAdded: old.dateAdded,
            fileSize: old.fileSize
        )
        entries = Self.sort(entries, by: sortOrder, reversed: isReversed)
        if let newIdx = entries.firstIndex(where: { Self.sameFile($0.url, newURL) }) {
            currentIndex = newIdx
        }
    }

    func resort(sortOrder: SortOrder, isReversed: Bool) {
        let prevURL = currentURL
        self.sortOrder = sortOrder
        self.isReversed = isReversed
        self.entries = Self.sort(entries, by: sortOrder, reversed: isReversed)
        if let prev = prevURL,
           let idx = entries.firstIndex(where: { Self.sameFile($0.url, prev) }) {
            currentIndex = idx
        } else {
            currentIndex = 0
        }
    }

    @discardableResult
    func removeCurrent() -> URL? {
        guard !entries.isEmpty, entries.indices.contains(currentIndex) else { return nil }
        entries.remove(at: currentIndex)
        if entries.isEmpty {
            currentIndex = 0
            return nil
        }
        if currentIndex >= entries.count {
            currentIndex = entries.count - 1
        }
        return entries[currentIndex].url
    }

    @discardableResult
    func next() -> URL? {
        guard !entries.isEmpty else { return nil }
        currentIndex = (currentIndex + 1) % entries.count
        return entries[currentIndex].url
    }

    @discardableResult
    func previous() -> URL? {
        guard !entries.isEmpty else { return nil }
        currentIndex = (currentIndex - 1 + entries.count) % entries.count
        return entries[currentIndex].url
    }

    static func scanFolder(of fileURL: URL) -> [Entry] {
        let folder = fileURL.deletingLastPathComponent()
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isHiddenKey,
            .contentModificationDateKey, .creationDateKey, .addedToDirectoryDateKey,
            .fileSizeKey
        ]
        guard let items = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return [makeEntry(url: fileURL)]
        }
        let filtered = items.filter { SupportedFormats.isSupported(url: $0) }
        return filtered.map(makeEntry)
    }

    private static func makeEntry(url: URL) -> Entry {
        let values = try? url.resourceValues(forKeys: [
            .contentModificationDateKey,
            .creationDateKey,
            .addedToDirectoryDateKey,
            .fileSizeKey
        ])
        return Entry(
            url: url,
            dateModified: values?.contentModificationDate,
            dateCreated: values?.creationDate,
            dateAdded: values?.addedToDirectoryDate,
            fileSize: Int64(values?.fileSize ?? 0)
        )
    }

    private static func sort(_ entries: [Entry], by order: SortOrder, reversed: Bool) -> [Entry] {
        let sorted = entries.sorted { a, b in
            switch order {
            case .name:
                return a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent) == .orderedAscending
            case .dateModified:
                return (a.dateModified ?? .distantPast) > (b.dateModified ?? .distantPast)
            case .dateCreated:
                return (a.dateCreated ?? .distantPast) > (b.dateCreated ?? .distantPast)
            case .dateAdded:
                return (a.dateAdded ?? .distantPast) > (b.dateAdded ?? .distantPast)
            case .fileSize:
                return a.fileSize > b.fileSize
            }
        }
        return reversed ? Array(sorted.reversed()) : sorted
    }

    private static func sameFile(_ a: URL, _ b: URL) -> Bool {
        a.standardizedFileURL == b.standardizedFileURL
    }
}
