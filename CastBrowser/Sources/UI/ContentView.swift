//
//  ContentView.swift
//  CastBrowser
//

import SwiftUI
import SwiftData
import WebKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TabItem.orderIndex) private var tabs: [TabItem]

    @State private var viewModel: BrowserViewModel?
    @State private var showingTabsSheet = false
    @State private var showingDetectedStreamsSheet = false
    @State private var showingRemoteSheet = false
    @FocusState private var isUrlFieldFocused: Bool

    var body: some View {
        NavigationStack {
            if let viewModel {
                VStack(spacing: 0) {
                    // Top Search / Location Bar
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        @Bindable var bindableVM = viewModel
                        TextField("Search or enter website name", text: $bindableVM.currentUrlText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .focused($isUrlFieldFocused)
                            .onSubmit {
                                viewModel.load(input: viewModel.currentUrlText)
                            }

                        if viewModel.isLoading {
                            Button(action: { viewModel.activeWebView?.stopLoading() }) {
                                Image(systemName: "xmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button(action: { viewModel.reload() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // Loading progress bar
                    if viewModel.isLoading {
                        ProgressView(value: viewModel.estimatedProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 2)
                    } else {
                        Divider()
                    }

                    // Main Browser Area (with explicit view identity to ensure instant tab switching)
                    ZStack {
                        if let webView = viewModel.activeWebView {
                            BrowserWebViewRepresentable(webView: webView)
                                .id(viewModel.currentTabId)
                                .ignoresSafeArea(.keyboard, edges: .bottom)
                        } else {
                            VStack(spacing: 16) {
                                Spacer()
                                ProgressView()
                                Text("Loading Tab...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }

                    // Floating Mini-Player for Active Cast Session
                    if CastSessionManager.shared.playbackState.status == .playing || CastSessionManager.shared.playbackState.status == .paused {
                        HStack(spacing: 12) {
                            Image(systemName: "tv.fill")
                                .foregroundColor(.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(CastSessionManager.shared.currentMediaTitle)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                Text(CastSessionManager.shared.activeDevice?.name ?? "Casting to TV")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                if CastSessionManager.shared.playbackState.status == .playing {
                                    CastSessionManager.shared.pause()
                                } else {
                                    CastSessionManager.shared.play()
                                }
                            }) {
                                Image(systemName: CastSessionManager.shared.playbackState.status == .playing ? "pause.fill" : "play.fill")
                                    .font(.title3)
                            }

                            Button(action: { showingRemoteSheet = true }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .onTapGesture {
                            showingRemoteSheet = true
                        }
                    }

                    Divider()

                    // Bottom Navigation Toolbar
                    HStack {
                        Button(action: { viewModel.goBack() }) {
                            Image(systemName: "chevron.backward")
                        }
                        .disabled(!viewModel.canGoBack)

                        Spacer()

                        Button(action: { viewModel.goForward() }) {
                            Image(systemName: "chevron.forward")
                        }
                        .disabled(!viewModel.canGoForward)

                        Spacer()

                        // Stream Detection & Cast Trigger Button
                        Button(action: {
                            if CastSessionManager.shared.playbackState.status == .playing || CastSessionManager.shared.playbackState.status == .paused {
                                showingRemoteSheet = true
                            } else {
                                showingDetectedStreamsSheet = true
                            }
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: viewModel.detectedStreams.isEmpty ? "tv" : "tv.badge.wifi.fill")
                                    .foregroundColor(viewModel.detectedStreams.isEmpty ? .primary : .accentColor)

                                if !viewModel.detectedStreams.isEmpty {
                                    Text("\(viewModel.detectedStreams.count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(3)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .offset(x: 10, y: -8)
                                }
                            }
                        }

                        Spacer()

                        Button(action: {}) {
                            Image(systemName: "clock")
                        }

                        Spacer()

                        Button(action: { showingTabsSheet = true }) {
                            HStack(spacing: 2) {
                                Image(systemName: "square.on.square")
                                if !tabs.isEmpty {
                                    Text("\(tabs.count)")
                                        .font(.caption2.bold())
                                }
                            }
                        }
                    }
                    .font(.title3)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
                .navigationTitle(viewModel.currentTitle)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showingDetectedStreamsSheet) {
                    DetectedStreamsSheet(
                        streams: viewModel.detectedStreams,
                        subtitles: viewModel.detectedSubtitles,
                        onCastStream: { stream, device in
                            Task {
                                let cookies = await viewModel.activeWebView?.configuration.websiteDataStore.httpCookieStore.allCookies() ?? []
                                let pageUrl = viewModel.activeWebView?.url
                                await CastSessionManager.shared.cast(
                                    stream: stream,
                                    to: device,
                                    pageUrl: pageUrl,
                                    cookies: cookies
                                )
                                showingRemoteSheet = true
                            }
                        }
                    )
                    .presentationDetents([.fraction(0.4), .medium, .large])
                }
                .sheet(isPresented: $showingRemoteSheet) {
                    CastRemoteSheet()
                        .presentationDetents([.medium, .large])
                }
            } else {
                ProgressView("Starting Browser...")
                    .task {
                        let vm = BrowserViewModel()
                        let repo = DataRepository(modelContext: modelContext)
                        vm.setRepository(repo)
                        CastSessionManager.shared.setRepository(repo)

                        let currentTabs = repo.getTabs()
                        if let activeTab = currentTabs.first(where: { $0.isActive }) ?? currentTabs.first {
                            await vm.activateTab(
                                id: activeTab.id,
                                urlString: activeTab.urlString,
                                title: activeTab.title
                            )
                        }
                        self.viewModel = vm
                    }
            }
        }
        .sheet(isPresented: $showingTabsSheet) {
            NavigationStack {
                List {
                    ForEach(tabs) { tab in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tab.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(tab.urlString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if tab.isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard let viewModel else { return }
                            Task {
                                let repo = DataRepository(modelContext: modelContext)
                                repo.setActiveTab(id: tab.id)
                                await viewModel.activateTab(id: tab.id, urlString: tab.urlString, title: tab.title)
                                showingTabsSheet = false
                            }
                        }
                    }
                    .onDelete { indexSet in
                        guard let viewModel else { return }
                        Task {
                            for index in indexSet {
                                await viewModel.closeTab(id: tabs[index].id)
                            }
                        }
                    }
                }
                .navigationTitle("Tabs (\(tabs.count))")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") {
                            showingTabsSheet = false
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            guard let viewModel else { return }
                            Task {
                                let repo = DataRepository(modelContext: modelContext)
                                let newTab = repo.createTab()
                                await viewModel.activateTab(id: newTab.id, urlString: newTab.urlString, title: newTab.title)
                                showingTabsSheet = false
                            }
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    ContentView()
}
