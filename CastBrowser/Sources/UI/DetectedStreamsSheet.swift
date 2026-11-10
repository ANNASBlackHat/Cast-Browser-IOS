//
//  DetectedStreamsSheet.swift
//  CastBrowser
//

import SwiftUI
import AVKit

struct DetectedStreamsSheet: View {
    let streams: [DetectedStream]
    let subtitles: [DetectedSubtitle]
    let onCastStream: (DetectedStream, CastDevice?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var previewPlayer: AVPlayer?
    @State private var showingLocalPlayer = false
    @State private var activeStreamForPlayer: DetectedStream?
    @State private var copiedUrl: String?
    @State private var showingDeviceSelector = false
    @State private var selectedStreamForCasting: DetectedStream?

    var body: some View {
        NavigationStack {
            List {
                if streams.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No Streams Detected Yet")
                            .font(.headline)
                        Text("Play a video on the page to trigger stream capture.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else {
                    Section("Detected Media (\(streams.count))") {
                        ForEach(streams) { stream in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(stream.format.badgeTitle)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(stream.format == .hls ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                                        .foregroundColor(stream.format == .hls ? .blue : .green)
                                        .cornerRadius(6)

                                    if let res = stream.resolution {
                                        Text(res)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text(stream.detectedAt, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Text(stream.title.isEmpty ? "Untitled Video" : stream.title)
                                    .font(.headline)
                                    .lineLimit(2)

                                Text(stream.url.absoluteString)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                                HStack(spacing: 12) {
                                    // 1. Cast Button
                                    Button(action: {
                                        selectedStreamForCasting = stream
                                        showingDeviceSelector = true
                                    }) {
                                        Label("Cast to TV", systemImage: "tv")
                                            .font(.subheadline.bold())
                                    }
                                    .buttonStyle(.borderedProminent)

                                    // 2. Local Preview / PiP Button
                                    Button(action: {
                                        activeStreamForPlayer = stream
                                        previewPlayer = AVPlayer(url: stream.url)
                                        showingLocalPlayer = true
                                    }) {
                                        Label("Preview", systemImage: "play.circle")
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.bordered)

                                    // 3. Copy Stream URL
                                    Button(action: {
                                        UIPasteboard.general.string = stream.url.absoluteString
                                        copiedUrl = stream.url.absoluteString
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            copiedUrl = nil
                                        }
                                    }) {
                                        Image(systemName: copiedUrl == stream.url.absoluteString ? "checkmark" : "doc.on.doc")
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    if !subtitles.isEmpty {
                        Section("Detected Subtitles (\(subtitles.count))") {
                            ForEach(subtitles) { sub in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sub.label)
                                            .font(.subheadline.bold())
                                        if !sub.language.isEmpty {
                                            Text(sub.language.uppercased())
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "captions.bubble")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Detected Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Choose Casting Device", isPresented: $showingDeviceSelector, titleVisibility: .visible) {
                Button("AirPlay 2 (Apple TV / Roku / Smart TV)") {
                    if let stream = selectedStreamForCasting {
                        onCastStream(stream, nil)
                        dismiss()
                    }
                }

                ForEach(CastSessionManager.shared.availableDlnaDevices) { device in
                    Button("\(device.name) (DLNA)") {
                        if let stream = selectedStreamForCasting {
                            onCastStream(stream, device)
                            dismiss()
                        }
                    }
                }

                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showingLocalPlayer, onDismiss: {
                previewPlayer?.pause()
                previewPlayer = nil
            }) {
                if let previewPlayer {
                    VideoPlayer(player: previewPlayer)
                        .ignoresSafeArea()
                        .onAppear {
                            previewPlayer.play()
                        }
                }
            }
            .task {
                await CastSessionManager.shared.refreshDlnaDevices()
            }
        }
    }
}
