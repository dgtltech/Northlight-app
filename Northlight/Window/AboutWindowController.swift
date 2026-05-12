import AppKit

@MainActor
final class AboutWindowController: NSWindowController {

    static let shared = AboutWindowController()

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let iconImageView = NSImageView()
        iconImageView.image = NSApp.applicationIconImage
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)

        let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? ProcessInfo.processInfo.processName
        let nameLabel = NSTextField(labelWithString: appName)
        nameLabel.font = NSFont.boldSystemFont(ofSize: 18)
        nameLabel.alignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? ""
        let versionLabel = NSTextField(labelWithString: "Version \(version) (\(build))")
        versionLabel.font = NSFont.systemFont(ofSize: 11)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(versionLabel)

        let creditsStack = NSStackView()
        creditsStack.orientation = .vertical
        creditsStack.alignment = .centerX
        creditsStack.spacing = 2
        creditsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(creditsStack)

        creditsStack.addArrangedSubview(makeRegular("Image viewer for macOS"))
        creditsStack.addArrangedSubview(spacer(8))
        creditsStack.addArrangedSubview(makeHeader("Built with"))
        creditsStack.addArrangedSubview(makeRegular("Swift · AppKit · ImageIO · UniformTypeIdentifiers"))
        creditsStack.addArrangedSubview(spacer(8))
        creditsStack.addArrangedSubview(makeHeader("Image format support"))
        creditsStack.addArrangedSubview(makeSmall("JPEG · PNG · GIF · TIFF · BMP · ICO · ICNS"))
        creditsStack.addArrangedSubview(makeSmall("HEIC · HEIF · WebP · AVIF · JPEG XL · PSD"))
        creditsStack.addArrangedSubview(spacer(8))
        creditsStack.addArrangedSubview(makeHeader("RAW formats"))
        let raws = [
            "Canon: CR2 · CR3 · CRW",
            "Nikon: NEF · NRW",
            "Sony: ARW · SRF · SR2",
            "Adobe: DNG",
            "Fujifilm: RAF",
            "Panasonic: RW2 · RWL",
            "Olympus: ORF",
            "Pentax: PEF · PTX",
            "Sigma: X3F",
            "Kodak: KDC · DCR",
            "Minolta: MRW",
            "Hasselblad: 3FR",
            "Epson: ERF",
            "Mamiya: MEF · MOS",
            "Phase One: IIQ"
        ]
        for raw in raws {
            creditsStack.addArrangedSubview(makeSmall(raw))
        }

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)

        let footerTextView = NSTextView()
        footerTextView.isEditable = false
        footerTextView.isSelectable = true
        footerTextView.drawsBackground = false
        footerTextView.textContainerInset = NSSize(width: 12, height: 8)
        footerTextView.linkTextAttributes = [
            .foregroundColor: NSColor(red: 0.97, green: 0.55, blue: 0.20, alpha: 1.0),
            .cursor: NSCursor.pointingHand
        ]

        let copyright = (Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String) ?? ""
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrString = NSMutableAttributedString()
        attrString.append(NSAttributedString(string: copyright + "  ·  ", attributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]))
        attrString.append(NSAttributedString(string: "Powered by RAGE", attributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor(red: 0.97, green: 0.55, blue: 0.20, alpha: 1.0),
            .link: URL(string: "https://rage.ac/welcome/")!,
            .paragraphStyle: paragraph
        ]))
        footerTextView.textStorage?.setAttributedString(attrString)
        footerTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerTextView)

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 96),
            iconImageView.heightAnchor.constraint(equalToConstant: 96),

            nameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 14),
            nameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            versionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            creditsStack.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 18),
            creditsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            creditsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            separator.topAnchor.constraint(greaterThanOrEqualTo: creditsStack.bottomAnchor, constant: 18),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: footerTextView.topAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            footerTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            footerTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            footerTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            footerTextView.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func makeRegular(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .labelColor
        label.alignment = .center
        return label
    }

    private func makeSmall(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 10)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        return label
    }

    private func makeHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: 12)
        label.textColor = .labelColor
        label.alignment = .center
        return label
    }

    private func spacer(_ height: CGFloat) -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    func showAndFocus() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
