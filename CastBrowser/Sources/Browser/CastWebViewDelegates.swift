//
//  CastWebViewDelegates.swift
//  CastBrowser
//

import Foundation
import WebKit

@MainActor
public protocol CastNavigationDelegateHandler: AnyObject {
    func didUpdateProgress(_ progress: Double)
    func didStartLoading()
    func didFinishLoading(title: String?, url: URL?)
    func didFailLoading(error: Error)
}

public final class CastUIDelegate: NSObject, WKUIDelegate {
    public static let shared = CastUIDelegate()

    // Suppress popup windows (e.g. target="_blank" redirects from ads)
    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // If user tapped a link that requested a new window, load it in the same webview
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    // Suppress automated JavaScript alerts from malicious sites
    public func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        // Automatically dismiss alert to prevent page freezing
        completionHandler()
    }
}

public final class CastNavigationDelegate: NSObject, WKNavigationDelegate {
    public weak var handler: CastNavigationDelegateHandler?
    private var progressObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?

    public init(handler: CastNavigationDelegateHandler? = nil) {
        self.handler = handler
        super.init()
    }

    public func attachObservations(to webView: WKWebView) {
        progressObservation?.invalidate()
        titleObservation?.invalidate()

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
            let progress = view.estimatedProgress
            Task { @MainActor [weak self] in
                self?.handler?.didUpdateProgress(progress)
            }
        }

        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] view, _ in
            let title = view.title
            let url = view.url
            Task { @MainActor [weak self] in
                self?.handler?.didFinishLoading(title: title, url: url)
            }
        }
    }

    public func detachObservations() {
        progressObservation?.invalidate()
        titleObservation?.invalidate()
        progressObservation = nil
        titleObservation = nil
    }

    // Intercept navigation requests
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

        // Block app-store / deep links from hijacked ads
        if scheme == "itms-appss" || scheme == "itms-services" || scheme == "market" || scheme == "intent" {
            decisionHandler(.cancel)
            return
        }

        // Allow http and https navigation
        if scheme == "http" || scheme == "https" || scheme == "about" {
            decisionHandler(.allow)
            return
        }

        // Cancel any unrecognized protocols
        decisionHandler(.cancel)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in
            handler?.didStartLoading()
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let title = webView.title
        let url = webView.url
        Task { @MainActor in
            handler?.didFinishLoading(title: title, url: url)
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            handler?.didFailLoading(error: error)
        }
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            handler?.didFailLoading(error: error)
        }
    }
}
