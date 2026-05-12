import Foundation
import CoreGraphics

enum ZoomState: Equatable {
    case fitToWindow
    case actualSize
    case custom(CGFloat)
}

final class ZoomController {
    static let minFactor: CGFloat = 0.05
    static let maxFactor: CGFloat = 32.0
    static let zoomStep: CGFloat = 1.25

    private(set) var state: ZoomState = .fitToWindow

    func resetForNewImage() {
        state = .fitToWindow
    }

    func setFitToWindow() {
        state = .fitToWindow
    }

    func setActualSize() {
        state = .actualSize
    }

    func setCustom(_ factor: CGFloat) {
        state = .custom(clamp(factor))
    }

    func nextZoomIn(from current: CGFloat) -> CGFloat {
        clamp(current * Self.zoomStep)
    }

    func nextZoomOut(from current: CGFloat) -> CGFloat {
        clamp(current / Self.zoomStep)
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(Self.maxFactor, max(Self.minFactor, value))
    }
}
