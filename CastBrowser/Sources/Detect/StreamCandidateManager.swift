//
//  StreamCandidateManager.swift
//  CastBrowser
//

import Foundation
import SwiftUI

@Observable
@MainActor
public final class StreamCandidateManager {
    public static let shared = StreamCandidateManager()

    // tabId -> list of detected streams
    private var streamsByTab: [UUID: [DetectedStream]] = [:]
    // tabId -> list of detected subtitles
    private var subtitlesByTab: [UUID: [DetectedSubtitle]] = [:]

    private init() {}

    public func streams(for tabId: UUID) -> [DetectedStream] {
        return streamsByTab[tabId] ?? []
    }

    public func subtitles(for tabId: UUID) -> [DetectedSubtitle] {
        return subtitlesByTab[tabId] ?? []
    }

    public func clearStreams(for tabId: UUID) {
        streamsByTab.removeValue(forKey: tabId)
        subtitlesByTab.removeValue(forKey: tabId)
    }

    public func registerCandidate(url: URL, pageUrl: URL, title: String, for tabId: UUID) async {
        // Filter obvious ad networks
        if StreamClassifier.isLikelyAdUrl(url: url) {
            return
        }

        // Deduplicate against already detected streams for this tab
        var current = streamsByTab[tabId] ?? []
        if current.contains(where: { $0.url == url }) {
            return
        }

        // Probe stream asynchronously
        let probe = await StreamProbeService.shared.probe(url: url, referer: pageUrl)
        guard probe.isValidMedia && !probe.isDrmProtected else { return }

        let detected = DetectedStream(
            url: url,
            pageUrl: pageUrl,
            title: title,
            format: probe.format,
            resolution: probe.resolution,
            contentLength: probe.contentLength,
            isDrmProtected: probe.isDrmProtected
        )

        // Prioritize master playlists at top
        if StreamClassifier.isMasterPlaylist(url: url) {
            current.insert(detected, at: 0)
        } else {
            current.append(detected)
        }

        streamsByTab[tabId] = current
    }

    public func registerSubtitle(url: URL, label: String, language: String, for tabId: UUID) {
        var current = subtitlesByTab[tabId] ?? []
        if current.contains(where: { $0.url == url }) {
            return
        }

        let sub = DetectedSubtitle(url: url, label: label, language: language)
        current.append(sub)
        subtitlesByTab[tabId] = current
    }
}
