//
//  TabStateManager.swift
//  CastBrowser
//

import Foundation
import WebKit

@MainActor
public final class TabStateManager {
    public static let shared = TabStateManager()

    private let fileManager = FileManager.default
    private let statesDirectory: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.statesDirectory = appSupport.appendingPathComponent("TabStates", isDirectory: true)

        if !fileManager.fileExists(atPath: statesDirectory.path) {
            try? fileManager.createDirectory(at: statesDirectory, withIntermediateDirectories: true)
        }
    }

    private func stateFileURL(for tabId: UUID) -> URL {
        return statesDirectory.appendingPathComponent("\(tabId.uuidString).state")
    }

    public func saveState(for tabId: UUID, from webView: WKWebView) {
        if #available(iOS 15.0, *) {
            guard let interactionState = webView.interactionState else { return }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: interactionState, requiringSecureCoding: false)
                try data.write(to: stateFileURL(for: tabId), options: .atomic)
            } catch {
                print("[TabStateManager] Failed to save interaction state for tab \(tabId): \(error)")
            }
        }
    }

    @discardableResult
    public func restoreState(for tabId: UUID, into webView: WKWebView) -> Bool {
        if #available(iOS 15.0, *) {
            let fileURL = stateFileURL(for: tabId)
            guard fileManager.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL) else {
                return false
            }

            do {
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.requiresSecureCoding = false
                if let interactionState = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) {
                    webView.interactionState = interactionState
                    return true
                }
            } catch {
                print("[TabStateManager] Failed to restore interaction state for tab \(tabId): \(error)")
            }
        }
        return false
    }

    public func deleteState(for tabId: UUID) {
        let fileURL = stateFileURL(for: tabId)
        try? fileManager.removeItem(at: fileURL)
    }
}
