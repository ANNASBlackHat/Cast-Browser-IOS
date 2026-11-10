//
//  WatchEntry.swift
//  CastBrowser
//

import Foundation
import SwiftData

@Model
public final class WatchEntry {
    @Attribute(.unique) public var id: UUID
    public var pageUrl: String
    public var streamUrl: String
    public var title: String
    public var seriesKey: String?
    public var season: Int?
    public var episode: Int?
    public var positionSeconds: Double
    public var durationSeconds: Double
    public var finished: Bool
    public var lastWatchedAt: Date

    public init(
        id: UUID = UUID(),
        pageUrl: String,
        streamUrl: String = "",
        title: String,
        seriesKey: String? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        positionSeconds: Double = 0.0,
        durationSeconds: Double = 0.0,
        finished: Bool = false,
        lastWatchedAt: Date = Date()
    ) {
        self.id = id
        self.pageUrl = pageUrl
        self.streamUrl = streamUrl
        self.title = title
        self.seriesKey = seriesKey
        self.season = season
        self.episode = episode
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
        self.finished = finished
        self.lastWatchedAt = lastWatchedAt
    }

    public var progressPercentage: Double {
        guard durationSeconds > 0 else { return 0.0 }
        return min(max(positionSeconds / durationSeconds, 0.0), 1.0)
    }
}
