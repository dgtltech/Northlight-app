import AppKit

@MainActor
final class PassthroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class PassthroughTextField: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPlaceholderStyle()
    }

    func applyPlaceholderStyle() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let pattern = Self.checkerboardPattern(dark: isDark)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .heavy),
            .foregroundColor: NSColor(patternImage: pattern),
            .kern: 2
        ]
        attributedStringValue = NSAttributedString(string: stringValue, attributes: attrs)
    }

    private static func checkerboardPattern(dark: Bool) -> NSImage {
        let tile: CGFloat = 16
        let half = tile / 2
        let (a, b): (NSColor, NSColor)
        if dark {
            a = NSColor(white: 0.28, alpha: 1.0)
            b = NSColor(white: 0.20, alpha: 1.0)
        } else {
            a = NSColor(white: 0.55, alpha: 1.0)
            b = NSColor(white: 0.40, alpha: 1.0)
        }
        return NSImage(size: NSSize(width: tile, height: tile), flipped: false) { rect in
            a.setFill()
            rect.fill()
            b.setFill()
            NSRect(x: 0, y: 0, width: half, height: half).fill()
            NSRect(x: half, y: half, width: half, height: half).fill()
            return true
        }
    }
}

@MainActor
final class ImageWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {

    private let scrollView = ImageScrollView()
    private let statusBar = StatusBarView()
    private let welcomeGuide = WelcomeGuideView()
    private let progressIndicator = NSProgressIndicator()
    private let zoomController = ZoomController()
    private var loadTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var spinnerTask: Task<Void, Never>?
    private var zoomPopover: NSPopover?
    private var currentURL: URL?
    private var folderNavigator: FolderNavigator?
    private var currentLoadedImage: LoadedImage?
    private var currentFileInfo: FileInfo?
    private var magnificationObservation: NSKeyValueObservation?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Northlight"
        window.center()
        window.setFrameAutosaveName("NorthlightMainWindow")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 400)
        self.init(window: window)
        window.delegate = self
        setupContentView()
        setupObservers()
        setupContextMenu()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupContentView() {
        guard let contentView = window?.contentView else { return }
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        statusBar.translatesAutoresizingMaskIntoConstraints = false

        scrollView.onFileDropped = { [weak self] url in
            self?.open(url: url)
        }
        scrollView.onArrowLeft = { [weak self] in
            self?.previousImage(nil)
        }
        scrollView.onArrowRight = { [weak self] in
            self?.nextImage(nil)
        }
        scrollView.onUserZoomed = { [weak self] mag in
            self?.zoomController.setCustom(mag)
            self?.refreshStatusBar()
        }
        scrollView.onImageChanged = { [weak self] hasImage in
            self?.welcomeGuide.isHidden = hasImage
        }
        statusBar.onFilenameClick = { [weak self] in
            self?.presentRenameDialog()
        }
        statusBar.onZoomClick = { [weak self] anchorView in
            self?.showZoomPopover(from: anchorView)
        }
        statusBar.onBackgroundCycle = {
            BackgroundPreferences.cycle()
        }

        contentView.addSubview(scrollView)
        contentView.addSubview(statusBar)

        welcomeGuide.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(welcomeGuide)

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .large
        progressIndicator.isIndeterminate = true
        progressIndicator.isHidden = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressIndicator)

        window?.initialFirstResponder = scrollView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 22),

            welcomeGuide.topAnchor.constraint(equalTo: scrollView.topAnchor),
            welcomeGuide.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            welcomeGuide.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            welcomeGuide.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            progressIndicator.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(backgroundPreferencesDidChange(_:)),
            name: BackgroundPreferences.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewWillStartLiveMagnify(_:)),
            name: NSScrollView.willStartLiveMagnifyNotification,
            object: scrollView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidEndLiveMagnify(_:)),
            name: NSScrollView.didEndLiveMagnifyNotification,
            object: scrollView
        )
        magnificationObservation = scrollView.observe(\.magnification, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshStatusBar()
            }
        }
    }

    private func setupContextMenu() {
        scrollView.contextMenuProvider = { [weak self] in
            self?.makeContextMenu()
        }
    }

    private func makeContextMenu() -> NSMenu? {
        guard currentURL != nil else { return nil }
        let menu = NSMenu()

        let openInPreview = NSMenuItem(title: "Open in Preview",
                                        action: #selector(openInPreview(_:)),
                                        keyEquivalent: "")
        openInPreview.target = self
        menu.addItem(openInPreview)

        let showInFinder = NSMenuItem(title: "Show in Finder",
                                       action: #selector(showInFinder(_:)),
                                       keyEquivalent: "")
        showInFinder.target = self
        menu.addItem(showInFinder)

        menu.addItem(.separator())

        let sendToItem = NSMenuItem(title: "Send to", action: nil, keyEquivalent: "")
        sendToItem.submenu = makeSendToMenu()
        menu.addItem(sendToItem)

        menu.addItem(.separator())

        let copyPath = NSMenuItem(title: "Copy File Path",
                                   action: #selector(copyFilePath(_:)),
                                   keyEquivalent: "")
        copyPath.target = self
        menu.addItem(copyPath)
        let copyName = NSMenuItem(title: "Copy Filename",
                                   action: #selector(copyFilename(_:)),
                                   keyEquivalent: "")
        copyName.target = self
        menu.addItem(copyName)

        let copyPhoto = NSMenuItem(title: "Copy Photo",
                                    action: #selector(copyPhoto(_:)),
                                    keyEquivalent: "")
        copyPhoto.target = self
        menu.addItem(copyPhoto)
        return menu
    }

    private func makeSendToMenu() -> NSMenu {
        let menu = NSMenu()
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
                                      action: #selector(sendToFolder(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.tag = index
                item.toolTip = folder.path
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let manage = NSMenuItem(title: "Manage Folders…",
                                action: #selector(showPreferences(_:)),
                                keyEquivalent: "")
        manage.target = self
        menu.addItem(manage)
        return menu
    }

    @objc private func backgroundPreferencesDidChange(_ notification: Notification) {
        scrollView.applyBackground()
        statusBar.refreshBackgroundButton()
    }

    @objc private func scrollViewWillStartLiveMagnify(_ notification: Notification) {
        scrollView.userDidMagnify()
    }

    @objc private func scrollViewDidEndLiveMagnify(_ notification: Notification) {
        scrollView.userDidMagnify()
        zoomController.setCustom(scrollView.magnification)
        refreshStatusBar()
    }

    func open(url: URL) {
        let folder = url.deletingLastPathComponent()
        let folderUnchanged = folderNavigator?.folder == folder

        if folderUnchanged {
            folderNavigator?.setCurrent(url: url)
        }

        currentURL = url
        currentLoadedImage = nil
        currentFileInfo = nil
        zoomController.resetForNewImage()
        refreshStatusBar()
        loadImage(url: url)

        if !folderUnchanged {
            folderNavigator = nil
            scanFolder(forFile: url)
        }
    }

    private func loadImage(url: URL) {
        loadTask?.cancel()
        spinnerTask?.cancel()

        spinnerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled, let self else { return }
            self.progressIndicator.isHidden = false
            self.progressIndicator.startAnimation(nil)
        }

        loadTask = Task { [weak self] in
            async let loadedAsync: LoadedImage = ImageLoader.load(url: url)
            async let infoAsync: FileInfo = Task.detached(priority: .userInitiated) {
                FileInfo.load(from: url)
            }.value

            do {
                let loaded = try await loadedAsync
                let info = await infoAsync
                try Task.checkCancellation()
                guard let self else { return }
                guard self.currentURL == url else { return }

                let nsImage = NSImage(data: loaded.data)
                if let nsImage {
                    nsImage.size = loaded.pixelSize
                    for rep in nsImage.representations {
                        rep.size = loaded.pixelSize
                    }
                }
                self.currentLoadedImage = loaded
                self.currentFileInfo = info
                self.scrollView.setImage(nsImage, pixelSize: loaded.pixelSize)
                self.refreshStatusBar()
                self.hideSpinner()
            } catch is CancellationError {
                self?.hideSpinner()
                return
            } catch {
                self?.hideSpinner()
                NSSound.beep()
            }
        }
    }

    private func showZoomPopover(from anchorView: NSView) {
        if let existing = zoomPopover, existing.isShown {
            existing.close()
            zoomPopover = nil
            return
        }
        let vc = ZoomPopoverViewController()
        vc.setMagnification(scrollView.magnification)
        vc.onZoomChanged = { [weak self] magnification in
            guard let self else { return }
            self.scrollView.userDidMagnify()
            self.scrollView.zoomTo(magnification)
            self.zoomController.setCustom(magnification)
            self.refreshStatusBar()
        }
        let popover = NSPopover()
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .maxY)
        zoomPopover = popover
    }

    private func hideSpinner() {
        spinnerTask?.cancel()
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
    }

    private func scanFolder(forFile fileURL: URL) {
        scanTask?.cancel()
        let targetFolder = fileURL.deletingLastPathComponent()
        let order = SortPreferences.order
        let reversed = SortPreferences.isReversed
        scanTask = Task { [weak self] in
            let entries = await Task.detached(priority: .userInitiated) {
                FolderNavigator.scanFolder(of: fileURL)
            }.value
            try? Task.checkCancellation()
            guard let self else { return }
            guard self.currentURL?.deletingLastPathComponent() == targetFolder else { return }

            self.folderNavigator = FolderNavigator(
                folder: targetFolder,
                entries: entries,
                currentURL: fileURL,
                sortOrder: order,
                isReversed: reversed
            )
            self.refreshStatusBar()
        }
    }

    private func refreshStatusBar() {
        let url = currentURL
        let pos = folderNavigator?.currentPosition
        let mag = scrollView.pixelSize.width > 0 ? scrollView.magnification : nil
        let frame: (current: Int, total: Int)? = {
            guard let count = currentLoadedImage?.frameCount, count > 0 else { return nil }
            return (1, count)
        }()
        let pixelSize = currentLoadedImage?.pixelSize
        let format = url.map { FileFormatName.display(for: $0) }
        let fileSize = currentFileInfo?.fileSize
        let date = currentFileInfo?.modificationDate
        let name = url?.lastPathComponent

        statusBar.update(
            folderPosition: pos,
            magnification: mag,
            frameInfo: frame,
            pixelSize: pixelSize,
            format: format,
            fileSize: fileSize,
            date: date,
            name: name
        )

        if let url = currentURL {
            window?.title = url.lastPathComponent
        } else {
            window?.title = "Northlight"
        }
    }

    @objc func zoomActualSize(_ sender: Any?) {
        scrollView.setActualSize()
        zoomController.setActualSize()
        refreshStatusBar()
    }

    @objc func zoomIn(_ sender: Any?) {
        let next = zoomController.nextZoomIn(from: scrollView.magnification)
        scrollView.zoomTo(next)
        refreshStatusBar()
    }

    @objc func zoomOut(_ sender: Any?) {
        let next = zoomController.nextZoomOut(from: scrollView.magnification)
        scrollView.zoomTo(next)
        refreshStatusBar()
    }

    @objc func zoomFit(_ sender: Any?) {
        scrollView.fitToWindow()
        zoomController.setFitToWindow()
        refreshStatusBar()
    }

    @objc func previousImage(_ sender: Any?) {
        guard let nav = folderNavigator, let url = nav.previous() else {
            NSSound.beep()
            return
        }
        open(url: url)
    }

    @objc func nextImage(_ sender: Any?) {
        guard let nav = folderNavigator, let url = nav.next() else {
            NSSound.beep()
            return
        }
        open(url: url)
    }

    @objc func moveToTrash(_ sender: Any?) {
        guard let url = currentURL else {
            NSSound.beep()
            return
        }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            showRenameError(message: "Could not move to Trash: \(error.localizedDescription)")
            return
        }

        if let nextURL = folderNavigator?.removeCurrent() {
            open(url: nextURL)
        } else {
            currentURL = nil
            currentLoadedImage = nil
            currentFileInfo = nil
            folderNavigator = nil
            scrollView.setImage(nil, pixelSize: .zero)
            refreshStatusBar()
        }
    }

    @objc func sortByName(_ sender: Any?) { setSortOrder(.name) }
    @objc func sortByDateModified(_ sender: Any?) { setSortOrder(.dateModified) }
    @objc func sortByDateCreated(_ sender: Any?) { setSortOrder(.dateCreated) }
    @objc func sortByDateAdded(_ sender: Any?) { setSortOrder(.dateAdded) }
    @objc func sortByFileSize(_ sender: Any?) { setSortOrder(.fileSize) }

    @objc func toggleReverseOrder(_ sender: Any?) {
        SortPreferences.isReversed.toggle()
        folderNavigator?.resort(sortOrder: SortPreferences.order, isReversed: SortPreferences.isReversed)
        refreshStatusBar()
    }

    private func setSortOrder(_ order: SortOrder) {
        SortPreferences.order = order
        folderNavigator?.resort(sortOrder: order, isReversed: SortPreferences.isReversed)
        refreshStatusBar()
    }

    @objc func showInFinder(_ sender: Any?) {
        guard let url = currentURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc func openInPreview(_ sender: Any?) {
        guard let url = currentURL else { return }
        let previewURL = URL(fileURLWithPath: "/System/Applications/Preview.app")
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: previewURL, configuration: config) { [weak self] _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.showRenameError(message: "Could not open in Preview: \(error.localizedDescription)")
            }
        }
    }

    @objc func sendToFolder(_ sender: NSMenuItem) {
        guard let url = currentURL else { return }
        let folders = SendToFolders.all
        guard folders.indices.contains(sender.tag) else { return }
        let folder = folders[sender.tag]
        let folderURL = folder.url

        let dest = folderURL.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path(percentEncoded: false)) {
            showRenameError(message: "A file named “\(url.lastPathComponent)” already exists in that folder.")
            return
        }
        do {
            try FileManager.default.moveItem(at: url, to: dest)
        } catch {
            showRenameError(message: "Could not move file: \(error.localizedDescription)")
            return
        }

        if let nextURL = folderNavigator?.removeCurrent() {
            open(url: nextURL)
        } else {
            currentURL = nil
            currentLoadedImage = nil
            currentFileInfo = nil
            folderNavigator = nil
            scrollView.setImage(nil, pixelSize: .zero)
            refreshStatusBar()
        }
    }

    @objc func showPreferences(_ sender: Any?) {
        PreferencesWindowController.shared.showAndFocus()
    }

    @objc func copyFilePath(_ sender: Any?) {
        guard let url = currentURL else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path(percentEncoded: false), forType: .string)
    }

    @objc func copyFilename(_ sender: Any?) {
        guard let url = currentURL else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.lastPathComponent, forType: .string)
    }

    @objc func copyPhoto(_ sender: Any?) {
        guard let image = scrollView.currentImage else {
            NSSound.beep()
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    private func presentRenameDialog() {
        guard let url = currentURL, let window else { return }

        let currentName = url.lastPathComponent
        let baseName = (currentName as NSString).deletingPathExtension

        let alert = NSAlert()
        alert.messageText = "Rename File"
        alert.informativeText = "Enter a new name for \(currentName)"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        textField.stringValue = currentName
        alert.accessoryView = textField

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            self?.performRename(originalURL: url, newName: newName)
        }

        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
            if let editor = textField.currentEditor() {
                editor.selectedRange = NSRange(location: 0, length: (baseName as NSString).length)
            }
        }
    }

    private func performRename(originalURL: URL, newName: String) {
        guard !newName.isEmpty else {
            showRenameError(message: "Name cannot be empty.")
            return
        }
        guard !newName.contains("/"), !newName.hasPrefix(".") else {
            showRenameError(message: "Name contains invalid characters.")
            return
        }
        let newURL = originalURL.deletingLastPathComponent().appendingPathComponent(newName)
        if newURL == originalURL { return }

        if FileManager.default.fileExists(atPath: newURL.path(percentEncoded: false)) {
            showRenameError(message: "A file named “\(newName)” already exists in this folder.")
            return
        }

        do {
            try FileManager.default.moveItem(at: originalURL, to: newURL)
        } catch {
            showRenameError(message: "Could not rename file: \(error.localizedDescription)")
            return
        }

        if currentURL == originalURL {
            currentURL = newURL
        }
        folderNavigator?.renameEntry(from: originalURL, to: newURL)
        refreshStatusBar()
    }

    private func showRenameError(message: String) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window, completionHandler: nil)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action
        let order = SortPreferences.order
        switch action {
        case #selector(sortByName(_:)):
            menuItem.state = order == .name ? .on : .off
            return true
        case #selector(sortByDateModified(_:)):
            menuItem.state = order == .dateModified ? .on : .off
            return true
        case #selector(sortByDateCreated(_:)):
            menuItem.state = order == .dateCreated ? .on : .off
            return true
        case #selector(sortByDateAdded(_:)):
            menuItem.state = order == .dateAdded ? .on : .off
            return true
        case #selector(sortByFileSize(_:)):
            menuItem.state = order == .fileSize ? .on : .off
            return true
        case #selector(toggleReverseOrder(_:)):
            menuItem.state = SortPreferences.isReversed ? .on : .off
            return true
        case #selector(previousImage(_:)), #selector(nextImage(_:)):
            return (folderNavigator?.count ?? 0) > 1
        case #selector(moveToTrash(_:)):
            return currentURL != nil
        case #selector(copyPhoto(_:)):
            return scrollView.currentImage != nil
        case #selector(showInFinder(_:)),
             #selector(openInPreview(_:)),
             #selector(copyFilePath(_:)),
             #selector(copyFilename(_:)):
            return currentURL != nil
        case #selector(sendToFolder(_:)):
            return currentURL != nil
        default:
            return true
        }
    }
}
