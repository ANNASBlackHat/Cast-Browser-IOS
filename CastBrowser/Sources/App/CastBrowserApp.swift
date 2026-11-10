//
//  CastBrowserApp.swift
//  CastBrowser
//

import SwiftUI
import SwiftData

@main
struct CastBrowserApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TabItem.self,
            WatchEntry.self,
            HistoryVisit.self,
            BookmarkItem.self,
            CastDeviceItem.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
