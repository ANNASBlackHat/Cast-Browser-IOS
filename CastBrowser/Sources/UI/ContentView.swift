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

                        Button(action: {}) {
                            Image(systemName: "airplayvideo")
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
            } else {
                ProgressView("Starting Browser...")
                    .task {
                        let vm = BrowserViewModel()
                        let repo = DataRepository(modelContext: modelContext)
                        vm.setRepository(repo)

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
