import AppKit

@MainActor
final class WelcomeGuideView: NSView {

    private let panel = NSVisualEffectView()
    private let subtitleLabel = NSTextField(labelWithString: "Drop or open an image to start")
    private let leftColumn = NSStackView()
    private let rightColumn = NSStackView()
    private let columnsRow = NSStackView()
    private let collapseButton = NSButton()
    private let expandButton = NSButton()
    private let aboutButton = NSButton()

    private static let collapsedKey = "guide.collapsed"

    private let showsChrome: Bool

    init(showsChrome: Bool = true) {
        self.showsChrome = showsChrome
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        self.showsChrome = true
        super.init(coder: coder)
        configure()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if let hit {
            if hit === expandButton || hit.isDescendant(of: expandButton) {
                return expandButton
            }
            if hit === collapseButton || hit.isDescendant(of: collapseButton) {
                return collapseButton
            }
            if hit === aboutButton || hit.isDescendant(of: aboutButton) {
                return aboutButton
            }
        }
        return nil
    }

    private func configure() {
        panel.material = .hudWindow
        panel.blendingMode = .withinWindow
        panel.state = .active
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 16
        panel.layer?.masksToBounds = true
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)

        subtitleLabel.isBezeled = false
        subtitleLabel.isEditable = false
        subtitleLabel.isSelectable = false
        subtitleLabel.drawsBackground = false
        subtitleLabel.alignment = .center
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        leftColumn.orientation = .vertical
        leftColumn.alignment = .leading
        leftColumn.spacing = 10

        rightColumn.orientation = .vertical
        rightColumn.alignment = .leading
        rightColumn.spacing = 10

        populateLeftColumn()
        populateRightColumn()

        let leftWrap = NSStackView()
        leftWrap.orientation = .vertical
        leftWrap.alignment = .leading
        leftWrap.spacing = 12
        leftWrap.addArrangedSubview(makeHeader("Keyboard"))
        leftWrap.addArrangedSubview(leftColumn)

        let rightWrap = NSStackView()
        rightWrap.orientation = .vertical
        rightWrap.alignment = .leading
        rightWrap.spacing = 12
        rightWrap.addArrangedSubview(makeHeader("Mouse / Trackpad"))
        rightWrap.addArrangedSubview(rightColumn)

        columnsRow.orientation = .horizontal
        columnsRow.alignment = .top
        columnsRow.spacing = 50
        columnsRow.addArrangedSubview(leftWrap)
        columnsRow.addArrangedSubview(rightWrap)

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .centerX
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        if showsChrome {
            contentStack.addArrangedSubview(subtitleLabel)
            contentStack.setCustomSpacing(24, after: subtitleLabel)
        }
        contentStack.addArrangedSubview(columnsRow)

        let tipLabel = NSTextField(labelWithString: "Tip · To make Northlight the default app, use Settings → Defaults. Avoid Finder’s “Open With → Change All…” — macOS 15.4+ marks quarantined files as damaged on that path.")
        tipLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        tipLabel.textColor = .tertiaryLabelColor
        tipLabel.alignment = .center
        tipLabel.maximumNumberOfLines = 0
        tipLabel.preferredMaxLayoutWidth = 520
        tipLabel.lineBreakMode = .byWordWrapping
        contentStack.setCustomSpacing(20, after: columnsRow)
        contentStack.addArrangedSubview(tipLabel)

        panel.addSubview(contentStack)

        if showsChrome {
            let collapseImage = NSImage(systemSymbolName: "xmark.circle.fill",
                                        accessibilityDescription: "Collapse Guide")
            collapseButton.image = collapseImage
            collapseButton.imagePosition = .imageOnly
            collapseButton.bezelStyle = .accessoryBarAction
            collapseButton.isBordered = false
            collapseButton.contentTintColor = .secondaryLabelColor
            collapseButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            collapseButton.target = self
            collapseButton.action = #selector(handleCollapse(_:))
            collapseButton.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(collapseButton)

            expandButton.title = "Guide"
            expandButton.bezelStyle = .rounded
            expandButton.controlSize = .regular
            expandButton.target = self
            expandButton.action = #selector(handleExpand(_:))
            expandButton.translatesAutoresizingMaskIntoConstraints = false
            addSubview(expandButton)

            let rageAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor(red: 0.97, green: 0.55, blue: 0.20, alpha: 1.0)
            ]
            aboutButton.attributedTitle = NSAttributedString(string: "Powered by RAGE", attributes: rageAttrs)
            aboutButton.bezelStyle = .accessoryBarAction
            aboutButton.isBordered = false
            aboutButton.controlSize = .small
            aboutButton.target = self
            aboutButton.action = #selector(handlePoweredByRage(_:))
            aboutButton.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(aboutButton)
        }

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor),

            contentStack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 32),
            contentStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -32),
            contentStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 40),
            contentStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -40),

        ])

        if showsChrome {
            NSLayoutConstraint.activate([
                collapseButton.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
                collapseButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 10),
                collapseButton.widthAnchor.constraint(equalToConstant: 22),
                collapseButton.heightAnchor.constraint(equalToConstant: 22),

                aboutButton.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -10),
                aboutButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),

                expandButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                expandButton.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            applyCollapseState(UserDefaults.standard.bool(forKey: Self.collapsedKey), persist: false)
        }
    }

    private func makeHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func populateLeftColumn() {
        let items: [(keys: [String], description: String)] = [
            (["⌘", "O"], "Open file"),
            (["←", "→"], "Previous / Next image"),
            (["⌘", "C"], "Copy photo"),
            (["⌘", "0"], "Actual size (100%)"),
            (["⌘", "+"], "Zoom in"),
            (["⌘", "−"], "Zoom out"),
            (["⌘", "9"], "Fit to window"),
            (["⌘", "⌫"], "Move to Trash"),
            (["⌘", ","], "Settings")
        ]
        for item in items {
            leftColumn.addArrangedSubview(makeShortcutRow(keys: item.keys, description: item.description))
        }
    }

    private func populateRightColumn() {
        let items: [(symbol: String, name: String, description: String)] = [
            ("computermouse", "Mouse wheel", "Switch to next / previous image"),
            ("computermouse", "⌘ + Wheel", "Zoom in / out"),
            ("hand.draw", "Click & drag", "Pan when image is zoomed"),
            ("cursorarrow.click.2", "Double-click", "Toggle 100% at cursor / Fit"),
            ("cursorarrow.and.square.on.square.dashed", "Right-click", "Open context menu"),
            ("arrow.up.left.and.arrow.down.right.square", "Pinch (trackpad)", "Zoom in / out")
        ]
        for item in items {
            rightColumn.addArrangedSubview(makeGestureRow(symbol: item.symbol, name: item.name, description: item.description))
        }
    }

    private func makeShortcutRow(keys: [String], description: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY

        for (index, key) in keys.enumerated() {
            if index > 0 {
                let plus = NSTextField(labelWithString: "+")
                plus.font = NSFont.systemFont(ofSize: 12, weight: .regular)
                plus.textColor = .tertiaryLabelColor
                row.addArrangedSubview(plus)
            }
            row.addArrangedSubview(makeKeyBox(text: key))
        }

        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        descLabel.textColor = .labelColor

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: 6).isActive = true

        row.addArrangedSubview(spacer)
        row.addArrangedSubview(descLabel)
        return row
    }

    private func makeGestureRow(symbol: String, name: String, description: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor = .labelColor

        let separator = NSTextField(labelWithString: "·")
        separator.font = NSFont.systemFont(ofSize: 12)
        separator.textColor = .tertiaryLabelColor

        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor

        row.addArrangedSubview(icon)
        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(separator)
        row.addArrangedSubview(descLabel)
        return row
    }

    private func makeKeyBox(text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        label.alignment = .center
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let box = NSView()
        box.wantsLayer = true
        box.layer?.borderWidth = 1
        box.layer?.borderColor = NSColor.separatorColor.cgColor
        box.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.6).cgColor
        box.layer?.cornerRadius = 5
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -3),
            box.widthAnchor.constraint(greaterThanOrEqualToConstant: 28),
            box.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])

        return box
    }

    private func applyCollapseState(_ collapsed: Bool, persist: Bool) {
        panel.isHidden = collapsed
        expandButton.isHidden = !collapsed
        if persist {
            UserDefaults.standard.set(collapsed, forKey: Self.collapsedKey)
        }
    }

    @objc private func handleCollapse(_ sender: NSButton) {
        applyCollapseState(true, persist: true)
    }

    @objc private func handleExpand(_ sender: NSButton) {
        applyCollapseState(false, persist: true)
    }

    @objc private func handlePoweredByRage(_ sender: NSButton) {
        if let url = URL(string: "https://rage.ac/welcome/") {
            NSWorkspace.shared.open(url)
        }
    }
}
