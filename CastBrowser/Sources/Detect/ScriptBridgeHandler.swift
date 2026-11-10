//
//  ScriptBridgeHandler.swift
//  CastBrowser
//

import Foundation
import WebKit

@MainActor
public protocol ScriptBridgeDelegate: AnyObject {
    func didDetectStreamCandidate(url: URL, pageUrl: URL, title: String)
    func didDetectSubtitleCandidate(url: URL, label: String, language: String)
    func didUpdatePlaybackProgress(currentTime: Double, duration: Double, url: String, title: String, pageUrl: String)
}

// Retain-cycle-free proxy conforming to WKScriptMessageHandler
public final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: ScriptBridgeDelegate?

    public init(delegate: ScriptBridgeDelegate) {
        self.delegate = delegate
        super.init()
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            return
        }

        switch type {
        case "STREAM_CANDIDATE":
            guard let urlString = body["url"] as? String,
                  let url = URL(string: urlString),
                  let pageUrlString = body["pageUrl"] as? String,
                  let pageUrl = URL(string: pageUrlString) else { return }
            let title = (body["title"] as? String) ?? ""
            Task { @MainActor [weak self] in
                self?.delegate?.didDetectStreamCandidate(url: url, pageUrl: pageUrl, title: title)
            }

        case "SUBTITLE_CANDIDATE":
            guard let urlString = body["url"] as? String,
                  let url = URL(string: urlString) else { return }
            let label = (body["label"] as? String) ?? "Subtitle"
            let lang = (body["language"] as? String) ?? ""
            Task { @MainActor [weak self] in
                self?.delegate?.didDetectSubtitleCandidate(url: url, label: label, language: lang)
            }

        case "PLAYBACK_PROGRESS":
            let currentTime = (body["currentTime"] as? Double) ?? Double((body["currentTime"] as? Int) ?? 0)
            let duration = (body["duration"] as? Double) ?? Double((body["duration"] as? Int) ?? 0)
            let url = (body["url"] as? String) ?? ""
            let title = (body["title"] as? String) ?? ""
            let pageUrl = (body["pageUrl"] as? String) ?? ""
            Task { @MainActor [weak self] in
                self?.delegate?.didUpdatePlaybackProgress(
                    currentTime: currentTime,
                    duration: duration,
                    url: url,
                    title: title,
                    pageUrl: pageUrl
                )
            }

        default:
            break
        }
    }
}
