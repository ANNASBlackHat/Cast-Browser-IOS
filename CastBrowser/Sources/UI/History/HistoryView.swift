//
//  HistoryView.swift
//  CastBrowser
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HistoryVisit.visitedAt, order: .reverse) private var visits: [HistoryVisit]
    let onSelectUrl: (String) -> Void

    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss

    var filteredVisits: [HistoryVisit] {
        if searchText.isEmpty {
            return visits
        }
        return visits.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.urlString.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredVisits.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No Browsing History")
                            .font(.headline)
                        Text("Pages you visit will be logged here locally.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredVisits) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title.isEmpty ? item.host : item.title)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)

                                Text(item.urlString)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(item.visitedAt, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectUrl(item.urlString)
                            dismiss()
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(filteredVisits[index])
                        }
                        try? modelContext.save()
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search history")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !visits.isEmpty {
                        Button("Clear All", role: .destructive) {
                            let repo = DataRepository(modelContext: modelContext)
                            repo.clearHistory()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
