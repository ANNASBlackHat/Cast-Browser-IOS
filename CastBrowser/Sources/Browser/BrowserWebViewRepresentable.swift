//
//  BrowserWebViewRepresentable.swift
//  CastBrowser
//

import SwiftUI
import WebKit

public struct BrowserWebViewRepresentable: UIViewRepresentable {
    public let webView: WKWebView

    public init(webView: WKWebView) {
        self.webView = webView
    }

    public func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // Layout updates are managed automatically by UIKit/AutoLayout
    }
}
