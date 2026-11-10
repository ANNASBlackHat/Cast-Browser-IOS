//
//  WKWebViewPool.swift
//  CastBrowser
//

import Foundation
import UIKit
import WebKit

@MainActor
public final class WKWebViewPool {
    public static let shared = WKWebViewPool()

    private let maxLiveViews: Int = 3
    private var liveViews: [UUID: WKWebView] = [:]
    private var lruOrder: [UUID] = []

    private let sharedProcessPool = WKProcessPool()
    private var baseConfiguration: WKWebViewConfiguration?

    private init() {}

    public func getOrCreateWebView(for tabId: UUID, initialUrl: URL? = nil) async -> WKWebView {
        // Return existing cached view if available
        if let existing = liveViews[tabId] {
            touchTab(tabId)
            return existing
        }

        // Evict oldest view if limit reached
        if liveViews.count >= maxLiveViews {
            evictOldest()
        }

        // Build configuration with content blocker rules
        let configuration = await getBaseConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        // Device-appropriate User Agent: Desktop Safari UA on iPad, default Safari UA on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad {
            webView.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1"
        }

        webView.uiDelegate = CastUIDelegate.shared

        // Attempt restoring interactionState (history & scroll position) from disk
        let restored = TabStateManager.shared.restoreState(for: tabId, into: webView)
        if !restored, let initialUrl {
            webView.load(URLRequest(url: initialUrl))
        }

        liveViews[tabId] = webView
        lruOrder.append(tabId)
        return webView
    }

    public func removeWebView(for tabId: UUID) {
        if let view = liveViews.removeValue(forKey: tabId) {
            view.stopLoading()
            view.uiDelegate = nil
            view.navigationDelegate = nil
        }
        lruOrder.removeAll(where: { $0 == tabId })
        TabStateManager.shared.deleteState(for: tabId)
    }

    public func existingWebView(for tabId: UUID) -> WKWebView? {
        return liveViews[tabId]
    }

    private func touchTab(_ tabId: UUID) {
        lruOrder.removeAll(where: { $0 == tabId })
        lruOrder.append(tabId)
    }

    private func evictOldest() {
        guard let oldestId = lruOrder.first else { return }
        if let webView = liveViews[oldestId] {
            // Save state before deallocating
            TabStateManager.shared.saveState(for: oldestId, from: webView)
            webView.stopLoading()
            webView.uiDelegate = nil
            webView.navigationDelegate = nil
            liveViews.removeValue(forKey: oldestId)
        }
        lruOrder.removeFirst()
    }

    private func getBaseConfiguration() async -> WKWebViewConfiguration {
        if let existing = baseConfiguration {
            return existing
        }

        let config = WKWebViewConfiguration()
        config.processPool = sharedProcessPool
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let userContentController = WKUserContentController()

        // Attach native Safari content-blocking rule list
        if let ruleList = await ContentBlockerManager.shared.getOrCompileRules() {
            userContentController.add(ruleList)
        }

        config.userContentController = userContentController
        self.baseConfiguration = config
        return config
    }
}
