//
//  VideoPreviewPlayerView.swift
//  CastBrowser
//

import SwiftUI
import AVKit

struct VideoPreviewPlayerView: View {
    let stream: DetectedStream
    let onCast: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView("Loading Video...")
                        .tint(.white)
                        .foregroundColor(.white)
                }
            }
            .navigationTitle(stream.title.isEmpty ? "Video Preview" : stream.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        player?.pause()
                        player = nil
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                            Text("Done")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        player?.pause()
                        dismiss()
                        onCast()
                    }) {
                        Label("Cast", systemImage: "tv")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .onAppear {
                let avPlayer = AVPlayer(url: stream.url)
                self.player = avPlayer
                avPlayer.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }
}
