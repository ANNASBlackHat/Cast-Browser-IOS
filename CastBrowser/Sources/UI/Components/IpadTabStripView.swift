//
//  IpadTabStripView.swift
//  CastBrowser
//

import SwiftUI

struct IpadTabStripView: View {
    let tabs: [TabItem]
    let activeTabId: UUID?
    let onSelectTab: (TabItem) -> Void
    let onCloseTab: (TabItem) -> Void
    let onNewTab: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs) { tab in
                    let isActive = (tab.id == activeTabId)
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.caption2)
                            .foregroundColor(isActive ? .accentColor : .secondary)

                        Text(tab.title.isEmpty ? "New Tab" : tab.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .frame(maxWidth: 160, alignment: .leading)

                        Button(action: {
                            onCloseTab(tab)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isActive ? .primary : .secondary)
                                .padding(4)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isActive ? Color(uiColor: .systemBackground) : Color(uiColor: .tertiarySystemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                    .shadow(color: isActive ? Color.black.opacity(0.06) : Color.clear, radius: 2, y: 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectTab(tab)
                    }
                }

                // New Tab Button
                Button(action: onNewTab) {
                    Image(systemName: "plus")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.6))
    }
}
