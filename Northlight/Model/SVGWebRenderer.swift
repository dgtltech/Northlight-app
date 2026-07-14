import AppKit
import WebKit

enum SVGRenderError: Error {
    case timeout
    case navigationFailed
}

/// Renders SVG files that CoreSVG cannot draw faithfully (external images,
/// filters, stylesheets, scripts) through an offscreen WKWebView snapshot.
/// One shared instance serializes requests through a single web view; the
/// loaded page is kept so zoom re-renders skip the navigation step.
@MainActor
final class SVGWebRenderer: NSObject, WKNavigationDelegate {
    static let shared = SVGWebRenderer()

    private var webView: WKWebView?
    private var loadedURL: URL?
    private var loadedModificationDate: Date?
    private var navigationContinuation: CheckedContinuation<Void, Error>?
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var didWarmUp = false

    /// Spawns the WebKit processes ahead of time (~300–400 ms saved on the
    /// first render). Called when an SVG shows up — on open or when a folder
    /// scan finds one — so users who never view SVG pay nothing.
    func warmUp() {
        guard !didWarmUp else { return }
        didWarmUp = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.acquire()
            defer { self.release() }
            guard self.webView == nil else { return }
            let webView = self.ensureWebView(size: CGSize(width: 32, height: 32))
            webView.loadHTMLString("<!doctype html>", baseURL: nil)
            try? await self.waitForNavigation(timeout: 3)
        }
    }

    /// Raster budget for snapshots. snapshotWidth is in points and the returned
    /// raster is points × screen scale, so the cap is applied in device pixels.
    static func cappedPointWidth(desired: CGFloat, logicalSize: CGSize, backingScale: CGFloat) -> CGFloat {
        let maxPixels: CGFloat = 48_000_000
        guard logicalSize.width > 0, logicalSize.height > 0 else { return desired }
        let aspect = logicalSize.height / logicalSize.width
        let pixels = desired * backingScale * desired * aspect * backingScale
        guard pixels > maxPixels else { return desired }
        return (maxPixels / (aspect * backingScale * backingScale)).squareRoot()
    }

    func render(fileURL: URL, logicalSize: CGSize, pointWidth: CGFloat) async throws -> NSImage {
        await acquire()
        defer { release() }
        try Task.checkCancellation()

        let webView = ensureWebView(size: logicalSize)
        webView.frame = NSRect(origin: .zero, size: logicalSize)

        let modificationDate = (try? FileManager.default.attributesOfItem(
            atPath: fileURL.path(percentEncoded: false)))?[.modificationDate] as? Date
        if loadedURL != fileURL || loadedModificationDate != modificationDate {
            loadedURL = nil
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
            try await waitForNavigation(timeout: 5)
            // didFinish covers the main document; give subresources (referenced
            // images, fonts) a moment to decode before the first snapshot.
            try await Task.sleep(nanoseconds: 150_000_000)
            loadedURL = fileURL
            loadedModificationDate = modificationDate
        }

        try Task.checkCancellation()

        let configuration = WKSnapshotConfiguration()
        configuration.rect = NSRect(origin: .zero, size: logicalSize)
        configuration.snapshotWidth = NSNumber(value: Double(pointWidth))
        let image = try await webView.takeSnapshot(configuration: configuration)

        // Keep the logical size regardless of raster scale so scroll-view
        // layout and fit math are unaffected by re-renders.
        image.size = logicalSize
        for rep in image.representations {
            rep.size = logicalSize
        }
        return image
    }

    private func ensureWebView(size: CGSize) -> WKWebView {
        if let webView { return webView }
        let created = WKWebView(frame: NSRect(origin: .zero, size: size))
        created.navigationDelegate = self
        webView = created
        return created
    }

    // MARK: - Navigation waiting

    private func waitForNavigation(timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            navigationContinuation = continuation
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.finishNavigation(with: .failure(SVGRenderError.timeout))
            }
        }
    }

    private func finishNavigation(with result: Result<Void, Error>) {
        guard let continuation = navigationContinuation else { return }
        navigationContinuation = nil
        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishNavigation(with: .success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishNavigation(with: .failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishNavigation(with: .failure(error))
    }

    // MARK: - Serialization

    private func acquire() async {
        if !isBusy {
            isBusy = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty {
            isBusy = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
