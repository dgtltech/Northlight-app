import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowControllers: [ImageWindowController] = []
    private var pendingURLs: [URL] = []

    var keyWindowController: ImageWindowController? {
        if let key = NSApp.keyWindow?.windowController as? ImageWindowController {
            return key
        }
        return windowControllers.last
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppIconManager.applyOnLaunch()
        MainMenu.install()

        let wc = makeNewWindow()
        NSApp.activate(ignoringOtherApps: true)

        if let url = pendingURLs.first {
            pendingURLs.removeAll()
            wc.open(url: url)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if windowControllers.isEmpty {
            pendingURLs = urls
            return
        }
        let wc = makeNewWindow()
        NSApp.activate(ignoringOtherApps: true)
        wc.open(url: url)
    }

    @discardableResult
    func makeNewWindow() -> ImageWindowController {
        let wc = ImageWindowController()
        if let window = wc.window {
            offsetIfNeeded(window)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowWillClose(_:)),
                name: NSWindow.willCloseNotification,
                object: window
            )
        }
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
        windowControllers.append(wc)
        return wc
    }

    private func offsetIfNeeded(_ window: NSWindow) {
        guard windowControllers.count > 0 else { return }
        let offset: CGFloat = 24
        var frame = window.frame
        let count = CGFloat(windowControllers.count)
        frame.origin.x += offset * count
        frame.origin.y -= offset * count
        window.setFrame(frame, display: false)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windowControllers.removeAll { $0.window === window }
    }

    @objc func newWindow(_ sender: Any?) {
        makeNewWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showPreferences(_ sender: Any?) {
        PreferencesWindowController.shared.showAndFocus()
    }

    @objc func showAbout(_ sender: Any?) {
        AboutWindowController.shared.showAndFocus()
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.keyWindowController?.open(url: url)
        }
    }
}
