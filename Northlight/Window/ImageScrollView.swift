import AppKit

@MainActor
final class ImageScrollView: NSScrollView {

    var onFileDropped: ((URL) -> Void)?
    var contextMenuProvider: (() -> NSMenu?)?
    var onArrowLeft: (() -> Void)?
    var onArrowRight: (() -> Void)?
    var onUserZoomed: ((CGFloat) -> Void)?

    var onImageChanged: ((Bool) -> Void)?

    var currentImage: NSImage? { imageView.image }

    private let imageView = NSImageView()
    private(set) var pixelSize: CGSize = .zero
    private var logicalSize: CGSize = .zero
    private(set) var isFitMode: Bool = true

    private var lastWheelNavigateTime: TimeInterval = 0
    private var isPanning: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        let clip = CenteringClipView()
        clip.drawsBackground = false
        contentView = clip

        hasHorizontalScroller = true
        hasVerticalScroller = true
        autohidesScrollers = true
        scrollerStyle = .overlay
        allowsMagnification = true
        minMagnification = ZoomController.minFactor
        maxMagnification = ZoomController.maxFactor
        drawsBackground = true
        postsFrameChangedNotifications = true
        applyBackground()

        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.imageFrameStyle = .none
        imageView.animates = true
        imageView.frame = .zero
        imageView.translatesAutoresizingMaskIntoConstraints = true

        documentView = imageView

        registerForDraggedTypes([.fileURL])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: self
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleFrameDidChange(_ notification: Notification) {
        if isFitMode {
            applyFit()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyBackground()
    }

    func applyBackground() {
        let mode = BackgroundPreferences.mode
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        switch mode {
        case .themeDefault:
            backgroundColor = NSColor(patternImage: Self.makeCheckerboardImage(dark: isDark))
        case .themeOpposite:
            backgroundColor = NSColor(patternImage: Self.makeCheckerboardImage(dark: !isDark))
        case .pink, .green, .white, .black:
            backgroundColor = mode.displayColor
        }
    }

    private static func makeCheckerboardImage(dark: Bool) -> NSImage {
        let tileSize: CGFloat = 16
        let half = tileSize / 2
        let (lightColor, darkColor): (NSColor, NSColor)
        if dark {
            lightColor = NSColor(white: 0.10, alpha: 1.0)
            darkColor = NSColor(white: 0.04, alpha: 1.0)
        } else {
            lightColor = NSColor.white
            darkColor = NSColor(white: 0.85, alpha: 1.0)
        }
        return NSImage(size: NSSize(width: tileSize, height: tileSize), flipped: false) { rect in
            lightColor.setFill()
            rect.fill()
            darkColor.setFill()
            NSRect(x: 0, y: 0, width: half, height: half).fill()
            NSRect(x: half, y: half, width: half, height: half).fill()
            return true
        }
    }

    func setImage(_ nsImage: NSImage?, pixelSize: CGSize) {
        self.pixelSize = pixelSize
        if let nsImage, nsImage.size.width > 0, nsImage.size.height > 0 {
            self.logicalSize = nsImage.size
            imageView.image = nsImage
            imageView.frame = NSRect(origin: .zero, size: nsImage.size)
            onImageChanged?(true)
        } else {
            self.logicalSize = .zero
            imageView.image = nil
            imageView.frame = .zero
            onImageChanged?(false)
        }
        isFitMode = true
        applyFit()
    }

    // Swaps in a re-rendered raster of the same logical size (SVG zoom
    // re-sharpening). Frame, magnification, scroll position and fit mode are
    // untouched; the caller guarantees image.size equals the current one.
    func updateImagePreservingLayout(_ image: NSImage) {
        guard imageView.image != nil else { return }
        imageView.image = image
    }

    func fitToWindow() {
        isFitMode = true
        applyFit()
    }

    func setActualSize() {
        isFitMode = false
        magnification = 1.0
        centerDocument()
    }

    func zoomTo(_ factor: CGFloat) {
        isFitMode = false
        zoomToFactor(factor, anchor: nil)
    }

    private func zoomToFactor(_ target: CGFloat, anchor: NSPoint?) {
        let oldMag = magnification
        guard target != oldMag else { return }

        let anchorPoint = anchor ?? NSPoint(x: bounds.midX, y: bounds.midY)
        let oldOrigin = contentView.bounds.origin
        let docAnchor = NSPoint(
            x: oldOrigin.x + anchorPoint.x / oldMag,
            y: oldOrigin.y + anchorPoint.y / oldMag
        )

        magnification = target

        let newOrigin = NSPoint(
            x: docAnchor.x - anchorPoint.x / target,
            y: docAnchor.y - anchorPoint.y / target
        )
        contentView.scroll(to: newOrigin)
        reflectScrolledClipView(contentView)
    }

    func userDidMagnify() {
        isFitMode = false
    }

    private func applyFit() {
        guard logicalSize.width > 0, logicalSize.height > 0 else { return }
        let containerSize = bounds.size
        guard containerSize.width > 0, containerSize.height > 0 else { return }

        let raw = min(containerSize.width / logicalSize.width,
                      containerSize.height / logicalSize.height)
        let target = max(ZoomController.minFactor, min(ZoomController.maxFactor, raw))
        magnification = target
        centerDocument()
    }

    private func centerDocument() {
        guard logicalSize.width > 0, logicalSize.height > 0 else { return }
        let visibleSize = contentView.bounds.size
        let scrollPoint = NSPoint(
            x: logicalSize.width / 2 - visibleSize.width / 2,
            y: logicalSize.height / 2 - visibleSize.height / 2
        )
        contentView.scroll(to: scrollPoint)
        reflectScrolledClipView(contentView)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenuProvider?()
    }

    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            handleZoomScroll(event)
            return
        }

        let isMouseWheel = event.phase == [] && event.momentumPhase == []

        if isMouseWheel {
            if abs(event.deltaY) > 0 {
                let now = event.timestamp
                if now - lastWheelNavigateTime > 0.15 {
                    lastWheelNavigateTime = now
                    if event.deltaY > 0 {
                        onArrowLeft?()
                    } else {
                        onArrowRight?()
                    }
                }
                return
            }
            super.scrollWheel(with: event)
            return
        }

        super.scrollWheel(with: event)
    }

    private func handleZoomScroll(_ event: NSEvent) {
        let raw = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
        guard abs(raw) > 0 else { return }

        let sensitivity: CGFloat = 0.01
        let multiplier = 1.0 + (raw * sensitivity)
        let target = max(ZoomController.minFactor,
                         min(ZoomController.maxFactor, magnification * multiplier))
        guard target != magnification else { return }

        isFitMode = false
        zoomToFactor(target, anchor: nil)
        onUserZoomed?(target)
    }

    private var canPan: Bool {
        guard logicalSize.width > 0, logicalSize.height > 0 else { return false }
        let visibleSize = contentView.bounds.size
        return logicalSize.width > visibleSize.width || logicalSize.height > visibleSize.height
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            handleDoubleClick(event)
            return
        }
        if canPan {
            isPanning = true
            NSCursor.closedHand.push()
        } else {
            super.mouseDown(with: event)
        }
    }

    private func handleDoubleClick(_ event: NSEvent) {
        guard logicalSize.width > 0, logicalSize.height > 0 else { return }
        if abs(magnification - 1.0) < 0.01 {
            fitToWindow()
            onUserZoomed?(magnification)
        } else {
            isFitMode = false
            let pointInScrollView = convert(event.locationInWindow, from: nil)
            zoomToFactor(1.0, anchor: pointInScrollView)
            onUserZoomed?(1.0)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isPanning else {
            super.mouseDragged(with: event)
            return
        }
        var origin = contentView.bounds.origin
        origin.x -= event.deltaX / magnification
        origin.y += event.deltaY / magnification
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
    }

    override func mouseUp(with event: NSEvent) {
        if isPanning {
            isPanning = false
            NSCursor.pop()
        } else {
            super.mouseUp(with: event)
        }
    }


    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.numericPad)
        guard modifiers.isEmpty else {
            super.keyDown(with: event)
            return
        }
        let chars = event.charactersIgnoringModifiers ?? ""
        let leftArrow = String(utf16CodeUnits: [unichar(NSLeftArrowFunctionKey)], count: 1)
        let rightArrow = String(utf16CodeUnits: [unichar(NSRightArrowFunctionKey)], count: 1)
        if chars == leftArrow {
            onArrowLeft?()
            return
        }
        if chars == rightArrow {
            onArrowRight?()
            return
        }
        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        droppedURL(from: sender) != nil ? .copy : []
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let url = droppedURL(from: sender) else { return false }
        onFileDropped?(url)
        return true
    }

    private func droppedURL(from sender: any NSDraggingInfo) -> URL? {
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            return nil
        }
        return urls.first { SupportedFormats.isSupported(url: $0) }
    }
}

@MainActor
final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return rect }
        let docFrame = documentView.frame

        if rect.size.width > docFrame.size.width {
            rect.origin.x = (docFrame.size.width - rect.size.width) / 2
        }
        if rect.size.height > docFrame.size.height {
            rect.origin.y = (docFrame.size.height - rect.size.height) / 2
        }
        return rect
    }
}
