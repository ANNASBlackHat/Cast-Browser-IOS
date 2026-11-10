//
//  DataRepository.swift
//  CastBrowser
//

import Foundation
import SwiftData

@MainActor
public final class DataRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Tab Management

    public func getTabs() -> [TabItem] {
        var descriptor = FetchDescriptor<TabItem>(sortBy: [SortDescriptor(\.orderIndex)])
        do {
            let tabs = try modelContext.fetch(descriptor)
            if tabs.isEmpty {
                let initial = TabItem(urlString: "https://www.google.com", title: "New Tab", orderIndex: 0, isActive: true)
                modelContext.insert(initial)
                try? modelContext.save()
                return [initial]
            }
            return tabs
        } catch {
            print("Failed to fetch tabs: \(error)")
            return []
        }
    }

    public func createTab(urlString: String = "https://www.google.com", title: String = "New Tab") -> TabItem {
        let existing = getTabs()
        // Mark all other tabs as inactive
        for tab in existing {
            tab.isActive = false
        }
        let newTab = TabItem(
            urlString: urlString,
            title: title,
            orderIndex: existing.count,
            isActive: true
        )
        modelContext.insert(newTab)
        try? modelContext.save()
        return newTab
    }

    public func setActiveTab(id: UUID) {
        let tabs = getTabs()
        for tab in tabs {
            tab.isActive = (tab.id == id)
            if tab.id == id {
                tab.lastAccessedAt = Date()
            }
        }
        try? modelContext.save()
    }

    public func updateTab(id: UUID, urlString: String? = nil, title: String? = nil, scrollX: Double? = nil, scrollY: Double? = nil) {
        let tabs = getTabs()
        guard let tab = tabs.first(where: { $0.id == id }) else { return }

        if let urlString { tab.urlString = urlString }
        if let title { tab.title = title }
        if let scrollX { tab.scrollPositionX = scrollX }
        if let scrollY { tab.scrollPositionY = scrollY }
        tab.lastAccessedAt = Date()

        try? modelContext.save()
    }

    public func closeTab(id: UUID) {
        let tabs = getTabs()
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let wasActive = tabs[index].isActive
        modelContext.delete(tabs[index])

        let remaining = tabs.filter { $0.id != id }
        if remaining.isEmpty {
            _ = createTab()
            return
        }

        // Re-index remaining tabs
        for (i, tab) in remaining.enumerated() {
            tab.orderIndex = i
        }

        // If the closed tab was active, activate adjacent tab
        if wasActive {
            let newActiveIndex = min(index, remaining.count - 1)
            remaining[newActiveIndex].isActive = true
            remaining[newActiveIndex].lastAccessedAt = Date()
        }

        try? modelContext.save()
    }

    // MARK: - Watch Progress & Continue Watching

    public func saveWatchProgress(
        pageUrl: String,
        streamUrl: String = "",
        rawTitle: String,
        positionSeconds: Double,
        durationSeconds: Double
    ) {
        let parsed = EpisodeTitleParser.parse(rawTitle: rawTitle, url: pageUrl)
        let isFinished = durationSeconds > 0 && (positionSeconds / durationSeconds) >= 0.95

        var descriptor = FetchDescriptor<WatchEntry>(predicate: #Predicate { $0.pageUrl == pageUrl })
        do {
            let existingEntries = try modelContext.fetch(descriptor)
            if let entry = existingEntries.first {
                entry.streamUrl = streamUrl.isEmpty ? entry.streamUrl : streamUrl
                entry.title = parsed.title
                entry.seriesKey = parsed.seriesKey
                entry.season = parsed.season
                entry.episode = parsed.episode
                entry.positionSeconds = positionSeconds
                entry.durationSeconds = durationSeconds
                entry.finished = isFinished
                entry.lastWatchedAt = Date()
            } else {
                let newEntry = WatchEntry(
                    pageUrl: pageUrl,
                    streamUrl: streamUrl,
                    title: parsed.title,
                    seriesKey: parsed.seriesKey,
                    season: parsed.season,
                    episode: parsed.episode,
                    positionSeconds: positionSeconds,
                    durationSeconds: durationSeconds,
                    finished: isFinished,
                    lastWatchedAt: Date()
                )
                modelContext.insert(newEntry)
            }
            try? modelContext.save()
        } catch {
            print("Failed to save watch progress: \(error)")
        }
    }

    public func getContinueWatching(limit: Int = 10) -> [WatchEntry] {
        var descriptor = FetchDescriptor<WatchEntry>(
            predicate: #Predicate { !$0.finished && $0.positionSeconds > 5.0 },
            sortBy: [SortDescriptor(\.lastWatchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - History Visits

    public func recordHistory(urlString: String, title: String) {
        guard !urlString.isEmpty, !urlString.hasPrefix("about:") else { return }
        let visit = HistoryVisit(urlString: urlString, title: title)
        modelContext.insert(visit)
        try? modelContext.save()
    }

    public func clearHistory() {
        do {
            try modelContext.delete(model: HistoryVisit.self)
            try? modelContext.save()
        } catch {
            print("Failed to clear history: \(error)")
        }
    }
}
