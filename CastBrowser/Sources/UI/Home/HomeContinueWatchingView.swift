//
//  HomeContinueWatchingView.swift
//  CastBrowser
//

import SwiftUI
import SwiftData

struct HomeContinueWatchingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<WatchEntry> { !$0.finished && $0.positionSeconds > 5.0 },
        sort: \WatchEntry.lastWatchedAt,
        order: .reverse
    ) private var continueWatching: [WatchEntry]

    let onResumeUrl: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Category", selection: $selectedTab) {
                    Text("Continue Watching").tag(0)
                    Text("History").tag(1)
                    Text("Bookmarks").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                if selectedTab == 0 {
                    // Continue Watching Shelf
                    ScrollView {
                        if continueWatching.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tv.badge.wifi")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No Active Videos to Resume")
                                    .font(.headline)
                                Text("Videos you play will remember your timestamps here.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(continueWatching) { item in
                                    ContinueWatchingCard(item: item) {
                                        onResumeUrl(item.pageUrl)
                                        dismiss()
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                } else if selectedTab == 1 {
                    HistoryView(onSelectUrl: { url in
                        onResumeUrl(url)
                        dismiss()
                    })
                } else {
                    BookmarksView(onSelectUrl: { url in
                        onResumeUrl(url)
                        dismiss()
                    })
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
