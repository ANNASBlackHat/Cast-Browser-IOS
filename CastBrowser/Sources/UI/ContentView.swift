//
//  ContentView.swift
//  CastBrowser
//

import SwiftUI

struct ContentView: View {
    @State private var urlInput: String = "https://www.google.com"
    @State private var activeTabTitle: String = "New Tab"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Search / Location Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search or enter website name", text: $urlInput)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    if !urlInput.isEmpty {
                        Button(action: { urlInput = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                // Main Content View
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tv.and.mediabox")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)

                    Text("CastBrowser iOS")
                        .font(.title2.bold())

                    Text("Browse any streaming site and cast video directly to AirPlay or DLNA TVs.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)

                    Spacer()
                }

                Divider()

                // Bottom Navigation Toolbar
                HStack {
                    Button(action: {}) {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled(true)

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "chevron.forward")
                    }
                    .disabled(true)

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "airplayvideo")
                    }

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "clock")
                    }

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "square.on.square")
                    }
                }
                .font(.title3)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .navigationTitle(activeTabTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
