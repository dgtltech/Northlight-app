import AppKit

@MainActor
final class SendToMenuDelegate: NSObject, NSMenuDelegate {
    static let shared = SendToMenuDelegate()

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let folders = SendToFolders.all
        if folders.isEmpty {
            let placeholder = NSMenuItem(title: "No folders configured",
                                         action: nil,
                                         keyEquivalent: "")
            placeholder.isEnabled = false
            menu.addItem(placeholder)
        } else {
            for (index, folder) in folders.enumerated() {
                let item = NSMenuItem(title: folder.displayName,
                                      action: #selector(ImageWindowController.sendToFolder(_:)),
                                      keyEquivalent: "")
                item.tag = index
                item.toolTip = folder.path
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let manage = NSMenuItem(title: "Manage Folders…",
                                action: #selector(ImageWindowController.showPreferences(_:)),
                                keyEquivalent: "")
        menu.addItem(manage)
    }
}
