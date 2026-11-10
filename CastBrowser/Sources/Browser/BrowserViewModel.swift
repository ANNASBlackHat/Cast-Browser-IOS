//
//  BrowserViewModel.swift
//  CastBrowser
//

import Foundation
import SwiftUI
import WebKit

@Observable
public final class BrowserViewModel: CastNavigationDelegateHandler {
    @MainActor public var currentUrlText: String = ""
    @MainActor public var currentTitle: String = "New Tab"
    @MainActor public var isLoading: Bool = false
    @MainActor public var estimatedProgress: Double = 0.0
    @MainActor public var canGoBack: Bool = false
    @MainActor public var canGoForward: Bool = false
    @MainActor public var activeWebView: WKWebView?

    private var currentTabId: UUID?
    private let navigationDelegate: CastNavigationDelegate
    private var repository: DataRepository?

    public init() {
        self.navigationDelegate = CastNavigationDelegate()
        self.navigationDelegate.handler = self
    }

    @MainActor
    public func setRepository(_ repo: DataRepository) {
        self.repository = repo
    }

    @MainActor
    public func activateTab(id: UUID, urlString: String, title: String) async {
        self.currentTabId = id
        self.currentUrlText = urlString
        self.currentTitle = title

        let initialUrl = URL(string: urlString)
        let webView = await WKWebViewPool.shared.getOrCreateWebView(for: id, initialUrl: initialUrl)

        navigationDelegate.detachObservations()
        webView.navigationDelegate = navigationDelegate
        navigationDelegate.attachObservations(to: webView)

        self.activeWebView = webView
        updateNavigationState()
    }

    @MainActor
    public func load(input: String) {
        guard let webView = activeWebView else { return }

        let targetUrl: URL
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let validUrl = URL(string: trimmed), validUrl.scheme != nil, validUrl.host != nil {
            targetUrl = validUrl
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            targetUrl = URL(string: "https://\(trimmed)") ?? URL(string: "https://www.google.com")!
        } else {
            let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            targetUrl = URL(string: "https://www.google.com/search?q=\(query)")!
        }

        self.currentUrlText = targetUrl.absoluteString
        webView.load(URLRequest(url: targetUrl))
    }

    @MainActor
    public func goBack() {
        activeWebView?.goBack()
        updateNavigationState()
    }

    @MainActor
    public func goForward() {
        activeWebView?.goForward()
        updateNavigationState()
    }

    @MainActor
    public func reload() {
        activeWebView?.reload()
    }

    @MainActor
    private func updateNavigationState() {
        guard let webView = activeWebView else { return }
        self.canGoBack = webView.canGoBack
        self.canGoForward = webView.canGoForward
    }

    // MARK: - CastNavigationDelegateHandler

    @MainActor
    public func didUpdateProgress(_ progress: Double) {
        self.estimatedProgress = progress
        self.isLoading = progress < 1.0
    }

    @MainActor
    public func didStartLoading() {
        self.isLoading = true
        updateNavigationState()
    }

    @MainActor
    public func didFinishLoading(title: String?, url: URL?) {
        self.isLoading = false
        updateNavigationState()

        if let title = title, !title.isEmpty {
            self.currentTitle = title
        }
        if let url = url {
            self.currentUrlText = url.absoluteString
            if let tabId = currentTabId {
                repository?.updateTab(id: tabId, urlString: url.absoluteString, title: currentTitle)
                repository?.recordHistory(urlString: url.absoluteString, title: currentTitle)
            }
        }
    }

    @MainActor
    public func didFailLoading(error: Error) {
        self.isLoading = false
        updateNavigationState()
    }
}
