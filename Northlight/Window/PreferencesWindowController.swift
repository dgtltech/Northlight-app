import AppKit
import UniformTypeIdentifiers
import CoreServices
import Darwin

@MainActor
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class PreferencesWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    static let shared = PreferencesWindowController()

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let addButton = NSButton(title: "+", target: nil, action: nil)
    private let removeButton = NSButton(title: "−", target: nil, action: nil)

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.setFrameAutosaveName("NorthlightPreferencesWindow")
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        let guideItem = NSTabViewItem(identifier: "guide")
        guideItem.label = "Guide"
        guideItem.view = makeGuideTabView()
        tabView.addTabViewItem(guideItem)

        let foldersItem = NSTabViewItem(identifier: "folders")
        foldersItem.label = "Folders"
        foldersItem.view = makeFoldersTabView()
        tabView.addTabViewItem(foldersItem)

        let defaultsItem = NSTabViewItem(identifier: "defaults")
        defaultsItem.label = "Defaults"
        defaultsItem.view = makeDefaultsTabView()
        tabView.addTabViewItem(defaultsItem)

        let iconItem = NSTabViewItem(identifier: "icon")
        iconItem.label = "Icon"
        iconItem.view = makeIconTabView()
        tabView.addTabViewItem(iconItem)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    private func makeFoldersTabView() -> NSView {
        let container = NSView()

        let titleLabel = NSTextField(labelWithString: "Send To Folders")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let hint = NSTextField(labelWithString: "Folders shown in the “Send to” submenu of the right-click menu.")
        hint.textColor = .secondaryLabelColor
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hint)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        column.title = "Path"
        column.minWidth = 200
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.style = .inset
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(tableDoubleClick(_:))

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        addButton.bezelStyle = .smallSquare
        addButton.target = self
        addButton.action = #selector(addFolder(_:))
        addButton.translatesAutoresizingMaskIntoConstraints = false

        removeButton.bezelStyle = .smallSquare
        removeButton.target = self
        removeButton.action = #selector(removeFolder(_:))
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonsStack = NSStackView(views: [addButton, removeButton])
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = 0
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(buttonsStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            hint.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            hint.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: buttonsStack.topAnchor, constant: -8),

            buttonsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            buttonsStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            addButton.widthAnchor.constraint(equalToConstant: 28),
            removeButton.widthAnchor.constraint(equalToConstant: 28)
        ])

        return container
    }

    private var iconButtons: [NSButton] = []

    private func makeIconTabView() -> NSView {
        let container = NSView()

        let title = NSTextField(labelWithString: "Application Icon")
        title.font = NSFont.boldSystemFont(ofSize: 13)
        title.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(title)

        let hint = NSTextField(labelWithString: "Choose a preset or pick a custom image. Changes apply immediately to the Dock icon.")
        hint.textColor = .secondaryLabelColor
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 0
        hint.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hint)

        let grid = NSStackView()
        grid.orientation = .horizontal
        grid.spacing = 16
        grid.alignment = .top
        grid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)

        iconButtons.removeAll()
        for preset in AppIconManager.presets {
            let cell = makeIconCell(preset: preset)
            grid.addArrangedSubview(cell)
        }

        let resetButton = NSButton(title: "Reset to Default", target: self, action: #selector(resetIcon(_:)))
        resetButton.bezelStyle = .rounded
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonsRow = NSStackView(views: [resetButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.spacing = 12
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(buttonsRow)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            hint.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            hint.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            grid.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 16),
            grid.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            buttonsRow.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 24),
            buttonsRow.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])

        updateIconSelection()
        return container
    }

    private func makeIconCell(preset: IconPreset) -> NSView {
        let cell = NSView()

        let button = NSButton(image: AppIconManager.image(for: preset),
                               target: self,
                               action: #selector(selectPresetIcon(_:)))
        button.imageScaling = .scaleProportionallyUpOrDown
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.isBordered = true
        button.identifier = NSUserInterfaceItemIdentifier(preset.key)
        button.translatesAutoresizingMaskIntoConstraints = false
        iconButtons.append(button)

        let label = NSTextField(labelWithString: preset.displayName)
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(button)
        cell.addSubview(label)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: cell.topAnchor),
            button.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            button.widthAnchor.constraint(equalToConstant: 88),
            button.heightAnchor.constraint(equalToConstant: 88),

            label.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
        ])
        return cell
    }

    @objc private func selectPresetIcon(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue,
              let preset = AppIconManager.presets.first(where: { $0.key == key }) else { return }
        AppIconManager.selectPreset(preset)
        updateIconSelection()
    }

    @objc private func resetIcon(_ sender: Any?) {
        AppIconManager.resetToDefault()
        updateIconSelection()
    }

    private func updateIconSelection() {
        let selected = AppIconManager.selectedKey
        for button in iconButtons {
            let key = button.identifier?.rawValue ?? ""
            button.layer?.borderWidth = (key == selected) ? 3 : 0
            button.layer?.borderColor = NSColor.controlAccentColor.cgColor
            button.layer?.cornerRadius = 8
            button.wantsLayer = true
        }
    }

    private var defaultsRows: [(format: FormatHandler, button: NSButton, status: NSTextField)] = []

    private func makeDefaultsTabView() -> NSView {
        let container = NSView()

        let title = NSTextField(labelWithString: "Default Application")
        title.font = NSFont.boldSystemFont(ofSize: 13)
        title.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(title)

        let hint = NSTextField(wrappingLabelWithString: "Set Northlight as the default app for these image formats. Use the buttons below — do not use Finder’s “Open With → Change All…” (see the note about the macOS bug).")
        hint.textColor = .secondaryLabelColor
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.maximumNumberOfLines = 0
        hint.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hint)

        let bugBlock = makeBugInfoBlock()
        bugBlock.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bugBlock)

        let setAllButton = NSButton(title: "Set Northlight as Default for All",
                                     target: self,
                                     action: #selector(setAllDefaults(_:)))
        setAllButton.bezelStyle = .rounded

        let fixQuarantineButton = NSButton(title: "Fix Quarantine in Folder…",
                                            target: self,
                                            action: #selector(fixQuarantineInFolder(_:)))
        fixQuarantineButton.bezelStyle = .rounded

        let buttonsRow = NSStackView(views: [setAllButton, fixQuarantineButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.spacing = 10
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(buttonsRow)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        defaultsRows.removeAll()
        for format in FileFormatRegistry.formats {
            stack.addArrangedSubview(makeDefaultRow(format: format))
        }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        scroll.documentView = document
        scroll.drawsBackground = false
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            hint.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            hint.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            bugBlock.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 10),
            bugBlock.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            bugBlock.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            buttonsRow.topAnchor.constraint(equalTo: bugBlock.bottomAnchor, constant: 12),
            buttonsRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            scroll.topAnchor.constraint(equalTo: buttonsRow.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -8),
            document.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -2)
        ])

        refreshDefaultsStatus()
        return container
    }

    private func makeDefaultRow(format: FormatHandler) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let nameLabel = NSTextField(labelWithString: format.title)
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor = .labelColor

        let extLabel = NSTextField(labelWithString: format.extensionsDisplay)
        extLabel.font = NSFont.systemFont(ofSize: 11)
        extLabel.textColor = .secondaryLabelColor

        let leftStack = NSStackView(views: [nameLabel, extLabel])
        leftStack.orientation = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 1
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        statusLabel.textColor = NSColor.systemGreen

        let button = NSButton(title: "Set as Default", target: self, action: #selector(setDefaultForRow(_:)))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.identifier = NSUserInterfaceItemIdentifier(format.typeIdentifier)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(leftStack)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(statusLabel)
        row.addArrangedSubview(button)
        row.translatesAutoresizingMaskIntoConstraints = false

        defaultsRows.append((format, button, statusLabel))
        return row
    }

    @objc private func setDefaultForRow(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let format = FileFormatRegistry.formats.first(where: { $0.typeIdentifier == identifier }) else { return }
        _ = applyDefault(typeIdentifier: format.typeIdentifier)
        refreshDefaultsStatus()
    }

    @objc private func setAllDefaults(_ sender: NSButton) {
        for format in FileFormatRegistry.formats {
            _ = applyDefault(typeIdentifier: format.typeIdentifier)
        }
        refreshDefaultsStatus()
        guard let window else { return }
        let appURL = Bundle.main.bundleURL.standardizedFileURL
        var setCount = 0
        for entry in defaultsRows {
            guard let utType = entry.format.utType else { continue }
            if let currentDefault = NSWorkspace.shared.urlForApplication(toOpen: utType)?.standardizedFileURL,
               currentDefault == appURL {
                setCount += 1
            }
        }
        let total = FileFormatRegistry.formats.count
        let alert = NSAlert()
        alert.messageText = "Set as default for \(setCount) of \(total) formats"
        if setCount < total {
            alert.informativeText = "macOS reserves some image types for system apps and may silently keep the previous handler. Do NOT use Finder’s “Open With → Change All…” to force them — on macOS 15.4+ that path triggers the “damaged file” bug. See the note above for details."
        }
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }

    private func applyDefault(typeIdentifier: String) -> OSStatus {
        guard let bundleID = Bundle.main.bundleIdentifier else { return -1 }
        return LSSetDefaultRoleHandlerForContentType(
            typeIdentifier as CFString,
            .all,
            bundleID as CFString
        )
    }

    private func makeBugInfoBlock() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
        container.layer?.cornerRadius = 6
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.cgColor

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                                  accessibilityDescription: nil)
        iconView.contentTintColor = NSColor.systemOrange
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = NSTextField(labelWithString: "macOS 15.4+ “Always Open With” bug — not Northlight’s fault")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = .labelColor

        let headerStack = NSStackView(views: [iconView, titleLabel])
        headerStack.orientation = .horizontal
        headerStack.spacing = 6
        headerStack.alignment = .centerY

        let body = NSTextField(wrappingLabelWithString: "Since macOS Sequoia 15.4 (April 2025), using Finder → Get Info → “Open With → Change All…” on quarantined files (downloaded from Telegram, Safari, AirDrop, Messages, iCloud) flags them as damaged. Apple confirmed this is intentional Gatekeeper behavior — no app can suppress it. Use the buttons above to associate formats instead, and the “Fix Quarantine in Folder…” button to repair files that already triggered the bug.")
        body.font = NSFont.systemFont(ofSize: 11)
        body.textColor = .secondaryLabelColor
        body.maximumNumberOfLines = 0

        let linksRow = NSStackView()
        linksRow.orientation = .horizontal
        linksRow.spacing = 14
        linksRow.alignment = .centerY
        linksRow.addArrangedSubview(makeLinkButton(text: "lapcatsoftware.com — bug analysis",
                                                    urlString: "https://lapcatsoftware.com/articles/2025/4/8.html"))
        linksRow.addArrangedSubview(makeLinkButton(text: "mjtsai.com — summary",
                                                    urlString: "https://mjtsai.com/blog/2025/07/15/gatekeeper-change-in-macos-15-4/"))
        linksRow.addArrangedSubview(makeLinkButton(text: "Apple Developer Forums (DTS)",
                                                    urlString: "https://developer.apple.com/forums/thread/795994"))

        let stack = NSStackView(views: [headerStack, body, linksRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        return container
    }

    private func makeLinkButton(text: String, urlString: String) -> NSButton {
        let button = NSButton()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
        button.bezelStyle = .accessoryBarAction
        button.isBordered = false
        button.target = self
        button.action = #selector(openExternalLink(_:))
        button.identifier = NSUserInterfaceItemIdentifier(urlString)
        button.toolTip = urlString
        return button
    }

    @objc private func openExternalLink(_ sender: NSButton) {
        guard let urlString = sender.identifier?.rawValue,
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func fixQuarantineInFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Fix"
        panel.message = "Choose a folder. Northlight will recursively remove the quarantine flag from supported image files."
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.clearQuarantine(in: url)
        }
    }

    private func clearQuarantine(in folderURL: URL) {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard let enumerator = fm.enumerator(at: folderURL,
                                              includingPropertiesForKeys: keys,
                                              options: [.skipsHiddenFiles]) else { return }

        var total = 0
        var cleared = 0
        var failed = 0

        for case let fileURL as URL in enumerator {
            let isDir = (try? fileURL.resourceValues(forKeys: Set(keys)))?.isDirectory ?? false
            if isDir { continue }
            guard SupportedFormats.isSupported(url: fileURL) else { continue }
            total += 1

            let result = fileURL.path.withCString { cPath in
                Darwin.removexattr(cPath, "com.apple.quarantine", 0)
            }
            if result == 0 {
                cleared += 1
            } else if errno != ENOATTR {
                failed += 1
            }
        }

        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "Processed \(total) image file\(total == 1 ? "" : "s")"
        var lines: [String] = []
        if cleared > 0 { lines.append("Cleared quarantine on \(cleared) file\(cleared == 1 ? "" : "s")") }
        if cleared == 0 && total > 0 { lines.append("All files were already free of the quarantine flag.") }
        if failed > 0 { lines.append("\(failed) file\(failed == 1 ? "" : "s") could not be modified (permissions or read-only).") }
        if total == 0 { lines.append("No supported image files found in this folder.") }
        alert.informativeText = lines.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }

    private func refreshDefaultsStatus() {
        let appURL = Bundle.main.bundleURL.standardizedFileURL
        for entry in defaultsRows {
            guard let utType = entry.format.utType else {
                entry.status.stringValue = ""
                continue
            }
            if let currentDefault = NSWorkspace.shared.urlForApplication(toOpen: utType)?.standardizedFileURL,
               currentDefault == appURL {
                entry.status.stringValue = "✓ Default"
                entry.button.title = "Re-apply"
            } else {
                entry.status.stringValue = ""
                entry.button.title = "Set as Default"
            }
        }
    }

    private func makeGuideTabView() -> NSView {
        let container = NSView()
        let guide = WelcomeGuideView(showsChrome: false)
        guide.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(guide)
        NSLayoutConstraint.activate([
            guide.topAnchor.constraint(equalTo: container.topAnchor),
            guide.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            guide.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            guide.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        SendToFolders.all.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("PathCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier
            let text = NSTextField(labelWithString: "")
            text.lineBreakMode = .byTruncatingMiddle
            text.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(text)
            cell.textField = text
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        let folder = SendToFolders.all[row]
        cell.textField?.stringValue = folder.path
        cell.toolTip = folder.path
        return cell
    }

    @objc private func addFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let folder = SendToFolder(path: url.path(percentEncoded: false))
            SendToFolders.add(folder: folder)
            self?.tableView.reloadData()
        }
    }

    @objc private func removeFolder(_ sender: Any?) {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        SendToFolders.remove(at: row)
        tableView.reloadData()
    }

    @objc private func tableDoubleClick(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0 else { return }
        let folder = SendToFolders.all[row]
        NSWorkspace.shared.activateFileViewerSelecting([folder.url])
    }

    func showAndFocus() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        tableView.reloadData()
    }
}
