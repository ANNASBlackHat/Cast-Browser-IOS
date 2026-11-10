//
//  BrowserViewModel.swift
//  CastBrowser
//

import Foundation
import SwiftUI
import WebKit

@Observable
public final class BrowserViewModel: CastNavigationDelegateHandler {
    @MainActor public var currentTabId: UUID?
    @MainActor public var currentUrlText: String = ""
    @MainActor public var currentTitle: String = "New Tab"
    @MainActor public var isLoading: Bool = false
    @MainActor public var estimatedProgress: Double = 0.0
    @MainActor public var canGoBack: Bool = false
    @MainActor public var canGoForward: Bool = false
    @MainActor public var activeWebView: WKWebView?

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
        // Disconnect previous webview delegate to avoid cross-tab event leakage
        if let previousView = activeWebView, previousView !== WKWebViewPool.shared.existingWebView(for: id) {
            navigationDelegate.detachObservations()
            previousView.navigationDelegate = nil
        }

        self.currentTabId = id
        self.currentUrlText = urlString
        self.currentTitle = title

        let initialUrl = URL(string: urlString)
        let webView = await WKWebViewPool.shared.getOrCreateWebView(for: id, initialUrl: initialUrl)

        webView.navigationDelegate = navigationDelegate
        navigationDelegate.attachObservations(to: webView, for: id)

        self.activeWebView = webView
        updateNavigationState()
    }

    @MainActor
    public func closeTab(id: UUID) async {
        WKWebViewPool.shared.removeWebView(for: id)
        guard let repository else { return }

        repository.closeTab(id: id)
        let remainingTabs = repository.getTabs()

        if currentTabId == id {
            if let nextTab = remainingTabs.first(where: { $0.isActive }) ?? remainingTabs.first {
                await activateTab(id: nextTab.id, urlString: nextTab.urlString, title: nextTab.title)
            } else {
                activeWebView = nil
                currentTabId = nil
                currentUrlText = ""
                currentTitle = "New Tab"
            }
        }
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
    public func didUpdateProgress(_ progress: Double, for tabId: UUID) {
        guard tabId == currentTabId else { return }
        self.estimatedProgress = progress
        self.isLoading = progress < 1.0
    }

    @MainActor
    public func didStartLoading(for tabId: UUID) {
        guard tabId == currentTabId else { return }
        self.isLoading = true
        updateNavigationState()
    }

    @MainActor
    public func didUpdateTitle(_ title: String, for tabId: UUID) {
        if tabId == currentTabId {
            self.currentTitle = title
        }
        repository?.updateTab(id: tabId, title: title)
    }

    @MainActor
    public func didFinishLoading(title: String?, url: URL?, for tabId: UUID) {
        if tabId == currentTabId {
            self.isLoading = false
            updateNavigationState()

            if let title = title, !title.isEmpty {
                self.currentTitle = title
            }
            if let url = url {
                self.currentUrlText = url.absoluteString
            }
        }

        if let url = url {
            let finalTitle = title ?? currentTitle
            repository?.updateTab(id: tabId, urlString: url.absoluteString, title: finalTitle)
            repository?.recordHistory(urlString: url.absoluteString, title: finalTitle)
        }
    }

    @MainActor
    public func didFailLoading(error: Error, for tabId: UUID) {
        guard tabId == currentTabId else { return }
        self.isLoading = false
        updateNavigationState()
    }
}
