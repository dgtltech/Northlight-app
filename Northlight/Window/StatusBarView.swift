import AppKit

@MainActor
final class StatusBarView: NSView {

    var onFilenameClick: (() -> Void)?
    var onZoomClick: ((NSView) -> Void)?
    var onBackgroundCycle: (() -> Void)?

    let bgColorButton = NSButton()

    private let folderSection = StatusBarSection(symbol: "folder")
    private let zoomSection = StatusBarSection(symbol: "magnifyingglass")
    private let frameSection = StatusBarSection(symbol: "film")
    private let dimensionsSection = StatusBarSection(symbol: "viewfinder")
    private let formatLabel = StatusBarLabel()
    private let fileSizeSection = StatusBarSection(symbol: "doc")
    private let dateLabel = StatusBarLabel()
    private let nameLabel = StatusBarLabel()

    private let leftStack = NSStackView()
    private let rootStack = NSStackView()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 22)
    }

    private func configure() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.18, alpha: 1.0).cgColor

        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 12
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        bgColorButton.bezelStyle = .accessoryBarAction
        bgColorButton.isBordered = false
        bgColorButton.imagePosition = .imageOnly
        bgColorButton.target = self
        bgColorButton.action = #selector(handleBackgroundClick(_:))
        bgColorButton.toolTip = "Click to cycle background color"
        refreshBackgroundButton()

        leftStack.addArrangedSubview(bgColorButton)

        for v in [folderSection, zoomSection, frameSection, dimensionsSection, formatLabel, fileSizeSection, dateLabel] {
            leftStack.addArrangedSubview(v)
        }

        addSubview(leftStack)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.alignment = .right
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(nameLabel)

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleNameClick(_:)))
        nameLabel.addGestureRecognizer(click)
        nameLabel.toolTip = "Click to rename"

        let zoomClick = NSClickGestureRecognizer(target: self, action: #selector(handleZoomClick(_:)))
        zoomSection.addGestureRecognizer(zoomClick)
        zoomSection.toolTip = "Click to set zoom"

        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leftStack.trailingAnchor, constant: 12)
        ])

        clearAll()
    }

    func clearAll() {
        update(folderPosition: nil, magnification: nil, frameInfo: nil,
               pixelSize: nil, format: nil, fileSize: nil, date: nil, name: nil)
    }

    @objc private func handleNameClick(_ sender: NSClickGestureRecognizer) {
        onFilenameClick?()
    }

    @objc private func handleZoomClick(_ sender: NSClickGestureRecognizer) {
        onZoomClick?(zoomSection)
    }

    @objc private func handleBackgroundClick(_ sender: NSButton) {
        onBackgroundCycle?()
    }

    func refreshBackgroundButton() {
        bgColorButton.image = Self.makeBackgroundIcon(color: BackgroundPreferences.mode.displayColor)
    }

    private static func makeBackgroundIcon(color: NSColor) -> NSImage {
        let size: CGFloat = 14
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let inset: CGFloat = 1
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: inset, dy: inset))
            color.setFill()
            circle.fill()
            NSColor.labelColor.withAlphaComponent(0.55).setStroke()
            circle.lineWidth = 1
            circle.stroke()
            return true
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(nameLabel.frame, cursor: .pointingHand)
        addCursorRect(zoomSection.frame, cursor: .pointingHand)
    }

    func update(
        folderPosition: (index: Int, total: Int)?,
        magnification: CGFloat?,
        frameInfo: (current: Int, total: Int)?,
        pixelSize: CGSize?,
        format: String?,
        fileSize: Int64?,
        date: Date?,
        name: String?
    ) {
        if let p = folderPosition, p.total > 1 {
            folderSection.text = "\(p.index)/\(p.total)"
            folderSection.isHidden = false
        } else {
            folderSection.isHidden = true
        }

        if let m = magnification {
            zoomSection.text = "\(Int(round(m * 100)))%"
            zoomSection.isHidden = false
        } else {
            zoomSection.isHidden = true
        }

        if let f = frameInfo, f.total > 1 {
            frameSection.text = "\(f.current)/\(f.total)"
            frameSection.isHidden = false
        } else {
            frameSection.isHidden = true
        }

        if let s = pixelSize, s.width > 0, s.height > 0 {
            dimensionsSection.text = "\(Int(s.width))×\(Int(s.height))"
            dimensionsSection.isHidden = false
        } else {
            dimensionsSection.isHidden = true
        }

        if let fmt = format, !fmt.isEmpty {
            formatLabel.stringValue = fmt
            formatLabel.isHidden = false
        } else {
            formatLabel.isHidden = true
        }

        if let bytes = fileSize, bytes > 0 {
            fileSizeSection.text = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            fileSizeSection.isHidden = false
        } else {
            fileSizeSection.isHidden = true
        }

        if let d = date {
            dateLabel.stringValue = Self.dateFormatter.string(from: d)
            dateLabel.isHidden = false
        } else {
            dateLabel.isHidden = true
        }

        if let n = name, !n.isEmpty {
            nameLabel.stringValue = n
            nameLabel.isHidden = false
        } else {
            nameLabel.isHidden = true
        }
    }
}

@MainActor
final class StatusBarSection: NSStackView {
    private let imageView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    var text: String {
        get { label.stringValue }
        set { label.stringValue = newValue }
    }

    init(symbol: String) {
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = 4

        imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        imageView.contentTintColor = NSColor.secondaryLabelColor
        imageView.imageScaling = .scaleProportionallyDown
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)

        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = NSColor.labelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail

        addArrangedSubview(imageView)
        addArrangedSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
final class StatusBarLabel: NSTextField {
    init() {
        super.init(frame: .zero)
        isBezeled = false
        isEditable = false
        isSelectable = false
        drawsBackground = false
        font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        textColor = NSColor.labelColor
        maximumNumberOfLines = 1
        lineBreakMode = .byTruncatingTail
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
