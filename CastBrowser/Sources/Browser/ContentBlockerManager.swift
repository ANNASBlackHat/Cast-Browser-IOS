//
//  ContentBlockerManager.swift
//  CastBrowser
//

import Foundation
import WebKit

public actor ContentBlockerManager {
    public static let shared = ContentBlockerManager()

    private var compiledRuleList: WKContentRuleList?
    private let ruleListIdentifier = "CastBrowserAdBlockRules"

    private init() {}

    public func getOrCompileRules() async -> WKContentRuleList? {
        if let compiled = compiledRuleList {
            return compiled
        }

        // Check if already compiled in persistent store
        if let existing = try? await WKContentRuleListStore.default().contentRuleList(forIdentifier: ruleListIdentifier) {
            self.compiledRuleList = existing
            return existing
        }

        // Load JSON rules from bundle
        guard let url = Bundle.main.url(forResource: "AdBlockRules", withExtension: "json"),
              let jsonString = try? String(contentsOf: url, encoding: .utf8) else {
            print("[ContentBlocker] AdBlockRules.json not found in bundle, using default rules.")
            let fallbackRules = """
            [
              {"trigger": {"url-filter": ".*doubleclick.net.*"}, "action": {"type": "block"}},
              {"trigger": {"url-filter": ".*popads.net.*"}, "action": {"type": "block"}},
              {"trigger": {"url-filter": ".*propellerads.com.*"}, "action": {"type": "block"}}
            ]
            """
            return await compileRules(jsonString: fallbackRules)
        }

        return await compileRules(jsonString: jsonString)
    }

    private func compileRules(jsonString: String) async -> WKContentRuleList? {
        do {
            let list = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: ruleListIdentifier,
                encodedContentRuleList: jsonString
            )
            self.compiledRuleList = list
            return list
        } catch {
            print("[ContentBlocker] Failed to compile rules: \(error)")
            return nil
        }
    }
}
