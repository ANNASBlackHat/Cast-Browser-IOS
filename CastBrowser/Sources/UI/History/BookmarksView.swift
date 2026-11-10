//
//  BookmarksView.swift
//  CastBrowser
//

import SwiftUI
import SwiftData

struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookmarkItem.createdAt, order: .reverse) private var bookmarks: [BookmarkItem]
    let onSelectUrl: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if bookmarks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No Bookmarks Saved")
                            .font(.headline)
                        Text("Bookmark pages using the star icon in the address bar.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(bookmarks) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title.isEmpty ? "Saved Bookmark" : item.title)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)

                                Text(item.urlString)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectUrl(item.urlString)
                            dismiss()
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(bookmarks[index])
                        }
                        try? modelContext.save()
                    }
                }
            }
            .navigationTitle("Bookmarks")
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
