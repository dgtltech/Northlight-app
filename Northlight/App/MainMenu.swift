import AppKit

@MainActor
enum MainMenu {
    static func install() {
        let mainMenu = NSMenu()

        mainMenu.addItem(makeApplicationMenuItem())
        mainMenu.addItem(makeFileMenuItem())
        mainMenu.addItem(makeEditMenuItem())
        mainMenu.addItem(makeViewMenuItem())
        mainMenu.addItem(makeNavigateMenuItem())
        mainMenu.addItem(makeWindowMenuItem())

        NSApp.mainMenu = mainMenu
    }

    private static func makeApplicationMenuItem() -> NSMenuItem {
        let appName = ProcessInfo.processInfo.processName
        let item = NSMenuItem()
        let menu = NSMenu()
        item.submenu = menu

        menu.addItem(withTitle: "About \(appName)",
                     action: #selector(AppDelegate.showAbout(_:)),
                     keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…",
                     action: #selector(AppDelegate.showPreferences(_:)),
                     keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide \(appName)",
                     action: #selector(NSApplication.hide(_:)),
                     keyEquivalent: "h")
        let hideOthers = menu.addItem(withTitle: "Hide Others",
                                      action: #selector(NSApplication.hideOtherApplications(_:)),
                                      keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "Show All",
                     action: #selector(NSApplication.unhideAllApplications(_:)),
                     keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(appName)",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        return item
    }

    private static func makeFileMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "File")
        item.submenu = menu

        menu.addItem(withTitle: "New Window",
                     action: #selector(AppDelegate.newWindow(_:)),
                     keyEquivalent: "n")
        menu.addItem(withTitle: "Open…",
                     action: #selector(AppDelegate.openDocument(_:)),
                     keyEquivalent: "o")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close",
                     action: #selector(NSWindow.performClose(_:)),
                     keyEquivalent: "w")
        menu.addItem(.separator())
        let trashItem = menu.addItem(withTitle: "Move to Trash",
                                     action: #selector(ImageWindowController.moveToTrash(_:)),
                                     keyEquivalent: "\u{8}")
        trashItem.keyEquivalentModifierMask = .command
        return item
    }

    private static func makeEditMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")
        item.submenu = menu

        menu.addItem(withTitle: "Copy",
                     action: #selector(ImageWindowController.copyPhoto(_:)),
                     keyEquivalent: "c")

        menu.addItem(.separator())

        let deleteItem = menu.addItem(withTitle: "Delete",
                                      action: #selector(ImageWindowController.moveToTrash(_:)),
                                      keyEquivalent: "")

        menu.addItem(.separator())

        menu.addItem(withTitle: "Open in Preview",
                     action: #selector(ImageWindowController.openInPreview(_:)),
                     keyEquivalent: "")
        menu.addItem(withTitle: "Show in Finder",
                     action: #selector(ImageWindowController.showInFinder(_:)),
                     keyEquivalent: "")

        let sendToItem = NSMenuItem(title: "Send to", action: nil, keyEquivalent: "")
        let sendToMenu = NSMenu(title: "Send to")
        sendToMenu.delegate = SendToMenuDelegate.shared
        sendToItem.submenu = sendToMenu
        menu.addItem(sendToItem)

        menu.addItem(.separator())

        menu.addItem(withTitle: "Copy File Path",
                     action: #selector(ImageWindowController.copyFilePath(_:)),
                     keyEquivalent: "")
        menu.addItem(withTitle: "Copy Filename",
                     action: #selector(ImageWindowController.copyFilename(_:)),
                     keyEquivalent: "")

        _ = deleteItem
        return item
    }

    private static func makeViewMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "View")
        item.submenu = menu

        menu.addItem(withTitle: "Actual Size",
                     action: #selector(ImageWindowController.zoomActualSize(_:)),
                     keyEquivalent: "0")
        menu.addItem(withTitle: "Zoom In",
                     action: #selector(ImageWindowController.zoomIn(_:)),
                     keyEquivalent: "+")
        menu.addItem(withTitle: "Zoom Out",
                     action: #selector(ImageWindowController.zoomOut(_:)),
                     keyEquivalent: "-")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Fit to Window",
                     action: #selector(ImageWindowController.zoomFit(_:)),
                     keyEquivalent: "9")
        return item
    }

    private static func makeNavigateMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Navigate")
        item.submenu = menu

        let leftArrow = String(utf16CodeUnits: [unichar(NSLeftArrowFunctionKey)], count: 1)
        let rightArrow = String(utf16CodeUnits: [unichar(NSRightArrowFunctionKey)], count: 1)

        let prev = menu.addItem(withTitle: "Previous Image",
                                action: #selector(ImageWindowController.previousImage(_:)),
                                keyEquivalent: leftArrow)
        prev.keyEquivalentModifierMask = []

        let next = menu.addItem(withTitle: "Next Image",
                                action: #selector(ImageWindowController.nextImage(_:)),
                                keyEquivalent: rightArrow)
        next.keyEquivalentModifierMask = []

        menu.addItem(.separator())

        let sortItem = NSMenuItem(title: "Sort By", action: nil, keyEquivalent: "")
        let sortMenu = NSMenu(title: "Sort By")
        sortMenu.addItem(withTitle: "Name",
                         action: #selector(ImageWindowController.sortByName(_:)),
                         keyEquivalent: "")
        sortMenu.addItem(withTitle: "Date Modified",
                         action: #selector(ImageWindowController.sortByDateModified(_:)),
                         keyEquivalent: "")
        sortMenu.addItem(withTitle: "Date Created",
                         action: #selector(ImageWindowController.sortByDateCreated(_:)),
                         keyEquivalent: "")
        sortMenu.addItem(withTitle: "Date Added",
                         action: #selector(ImageWindowController.sortByDateAdded(_:)),
                         keyEquivalent: "")
        sortMenu.addItem(withTitle: "File Size",
                         action: #selector(ImageWindowController.sortByFileSize(_:)),
                         keyEquivalent: "")
        sortMenu.addItem(.separator())
        sortMenu.addItem(withTitle: "Reverse Order",
                         action: #selector(ImageWindowController.toggleReverseOrder(_:)),
                         keyEquivalent: "")
        sortItem.submenu = sortMenu
        menu.addItem(sortItem)

        return item
    }

    private static func makeWindowMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Window")
        item.submenu = menu

        menu.addItem(withTitle: "Minimize",
                     action: #selector(NSWindow.performMiniaturize(_:)),
                     keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom",
                     action: #selector(NSWindow.performZoom(_:)),
                     keyEquivalent: "")

        NSApp.windowsMenu = menu
        return item
    }
}
