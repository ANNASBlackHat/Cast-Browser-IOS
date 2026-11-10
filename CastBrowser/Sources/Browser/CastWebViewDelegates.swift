//
//  CastWebViewDelegates.swift
//  CastBrowser
//

import Foundation
import WebKit

@MainActor
public protocol CastNavigationDelegateHandler: AnyObject {
    func didUpdateProgress(_ progress: Double, for tabId: UUID)
    func didStartLoading(for tabId: UUID)
    func didUpdateTitle(_ title: String, for tabId: UUID)
    func didFinishLoading(title: String?, url: URL?, for tabId: UUID)
    func didFailLoading(error: Error, for tabId: UUID)
}

public final class CastUIDelegate: NSObject, WKUIDelegate {
    public static let shared = CastUIDelegate()

    // Suppress automated popup scripts, only allow explicit user link taps
    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Only load in place if initiated by a deliberate user tap (.linkActivated)
        if navigationAction.navigationType == .linkActivated && navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        // Suppress any automated/script-triggered popups or pop-unders
        return nil
    }

    public func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        // Automatically dismiss alerts from malicious sites to avoid blocking execution
        completionHandler()
    }
}

public final class CastNavigationDelegate: NSObject, WKNavigationDelegate {
    public weak var handler: CastNavigationDelegateHandler?
    public var boundTabId: UUID?

    private var progressObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?

    public init(boundTabId: UUID? = nil, handler: CastNavigationDelegateHandler? = nil) {
        self.boundTabId = boundTabId
        self.handler = handler
        super.init()
    }

    public func attachObservations(to webView: WKWebView, for tabId: UUID) {
        detachObservations()
        self.boundTabId = tabId

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
            guard let self, let tabId = self.boundTabId else { return }
            let progress = view.estimatedProgress
            Task { @MainActor [weak self] in
                self?.handler?.didUpdateProgress(progress, for: tabId)
            }
        }

        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] view, _ in
            guard let self, let tabId = self.boundTabId, let title = view.title, !title.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.handler?.didUpdateTitle(title, for: tabId)
            }
        }
    }

    public func detachObservations() {
        progressObservation?.invalidate()
        titleObservation?.invalidate()
        progressObservation = nil
        titleObservation = nil
    }

    // Intercept navigation requests & allow safe media schemes
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""

        // Block hijacked app-store / market / intent deep-links
        if scheme == "itms-appss" || scheme == "itms-services" || scheme == "market" || scheme == "intent" {
            decisionHandler(.cancel)
            return
        }

        // Allow web navigation & media buffer schemes (blob: is critical for HTML5 video MSE, data: for inline icons)
        if scheme == "http" || scheme == "https" || scheme == "about" || scheme == "blob" || scheme == "data" {
            decisionHandler(.allow)
            return
        }

        // Cancel any unrecognized schemes
        decisionHandler(.cancel)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard let tabId = boundTabId else { return }
        Task { @MainActor in
            handler?.didStartLoading(for: tabId)
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let tabId = boundTabId else { return }
        let title = webView.title
        let url = webView.url
        Task { @MainActor in
            handler?.didFinishLoading(title: title, url: url, for: tabId)
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let tabId = boundTabId else { return }
        Task { @MainActor in
            handler?.didFailLoading(error: error, for: tabId)
        }
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard let tabId = boundTabId else { return }
        Task { @MainActor in
            handler?.didFailLoading(error: error, for: tabId)
        }
    }
}
