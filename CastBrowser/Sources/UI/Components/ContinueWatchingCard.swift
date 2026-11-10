//
//  ContinueWatchingCard.swift
//  CastBrowser
//

import SwiftUI

struct ContinueWatchingCard: View {
    let item: WatchEntry
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let series = item.seriesKey, !series.isEmpty {
                    Text(series)
                        .font(.caption.bold())
                        .foregroundColor(.accentColor)
                }

                if let season = item.season, let episode = item.episode {
                    Text(String(format: "S%02dE%02d", season, episode))
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                }

                Spacer()

                Text(item.lastWatchedAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(item.title.isEmpty ? "Untitled Video" : item.title)
                .font(.headline)
                .lineLimit(2)

            // Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: item.progressPercentage, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 4)

                HStack {
                    Text(formatSeconds(item.positionSeconds))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)

                    Spacer()

                    if item.durationSeconds > 0 {
                        let remaining = max(item.durationSeconds - item.positionSeconds, 0)
                        Text("\(formatSeconds(remaining)) left")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack {
                Button(action: onResume) {
                    Label("Resume", systemImage: "play.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(14)
        .contentShape(Rectangle())
        .onTapGesture {
            onResume()
        }
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0))
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }
}
