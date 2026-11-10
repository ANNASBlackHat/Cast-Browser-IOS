//
//  CastRemoteSheet.swift
//  CastBrowser
//

import SwiftUI

struct CastRemoteSheet: View {
    @Bindable var sessionManager = CastSessionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var scrubPosition: Double = 0.0
    @State private var isScrubbing: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header device status
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: sessionManager.activeDevice?.protocolType == .dlna ? "tv" : "airplayvideo")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                        Text(sessionManager.activeDevice?.name ?? "AirPlay / DLNA TV")
                            .font(.headline)
                    }

                    Text(sessionManager.currentMediaTitle.isEmpty ? "Connected Video Stream" : sessionManager.currentMediaTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 16)

                Spacer()

                // Playback Slider / Scrubber
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { isScrubbing ? scrubPosition : sessionManager.playbackState.positionSeconds },
                            set: { newValue in
                                scrubPosition = newValue
                                isScrubbing = true
                            }
                        ),
                        in: 0...max(sessionManager.playbackState.durationSeconds, 1.0),
                        onEditingChanged: { editing in
                            if !editing {
                                sessionManager.seek(to: scrubPosition)
                                isScrubbing = false
                            }
                        }
                    )
                    .tint(.blue)

                    HStack {
                        Text(formatSeconds(isScrubbing ? scrubPosition : sessionManager.playbackState.positionSeconds))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(formatSeconds(sessionManager.playbackState.durationSeconds))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)

                // Playback Control Buttons
                HStack(spacing: 36) {
                    // -15s Button
                    Button(action: {
                        let target = max(sessionManager.playbackState.positionSeconds - 15.0, 0.0)
                        sessionManager.seek(to: target)
                    }) {
                        Image(systemName: "gobackward.15")
                            .font(.title)
                    }

                    // Main Play / Pause Button
                    Button(action: {
                        if sessionManager.playbackState.status == .playing {
                            sessionManager.pause()
                        } else {
                            sessionManager.play()
                        }
                    }) {
                        Image(systemName: sessionManager.playbackState.status == .playing ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor)
                    }

                    // +15s Button
                    Button(action: {
                        let target = min(sessionManager.playbackState.positionSeconds + 15.0, sessionManager.playbackState.durationSeconds)
                        sessionManager.seek(to: target)
                    }) {
                        Image(systemName: "goforward.15")
                            .font(.title)
                    }
                }

                Spacer()

                // Bottom Actions: Disconnect / AirPlay Route Picker
                HStack(spacing: 16) {
                    Button(role: .destructive, action: {
                        sessionManager.stop()
                        dismiss()
                    }) {
                        Label("Disconnect", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    AirPlayRoutePicker()
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .navigationTitle("Remote Control")
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
