//
//  CastDevicePickerSheet.swift
//  CastBrowser
//

import SwiftUI
import AVKit

struct CastDevicePickerSheet: View {
    let stream: DetectedStream
    let onSelectDevice: (CastDevice?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var manualIpInput: String = ""
    @State private var isProbingManualIp: Bool = false
    @State private var manualIpError: String?

    var body: some View {
        NavigationStack {
            List {
                // Section 1: AirPlay 2 (Recommended for Apple TV, Roku, modern Samsung, LG, Sony)
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "airplayvideo")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("AirPlay 2 (System Audio/Video)")
                                    .font(.headline)
                                Text("Apple TV, Roku, modern Samsung, LG, Sony TVs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Embedded native AirPlay picker button
                            AirPlayRoutePicker(tintColor: .systemBlue, activeTintColor: .systemBlue)
                                .frame(width: 44, height: 44)
                        }

                        Button(action: {
                            onSelectDevice(nil) // Route to AirPlay 2
                            dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Text("Cast via AirPlay 2")
                                    .font(.subheadline.bold())
                                Image(systemName: "arrow.right.circle.fill")
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Wireless Casting (AirPlay 2)")
                } footer: {
                    Text("Tap the AirPlay icon above or button to choose your TV directly from iOS.")
                }

                // Section 2: DLNA Smart TVs on Local Wi-Fi
                Section {
                    if CastSessionManager.shared.isDiscoveringDevices {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Scanning Wi-Fi for Smart TVs...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if CastSessionManager.shared.availableDlnaDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No DLNA TVs Found Automatically")
                                .font(.subheadline.bold())
                            Text("Make sure your TV is turned on and connected to the same Wi-Fi network. You can also connect directly by entering its IP address below.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    } else {
                        ForEach(CastSessionManager.shared.availableDlnaDevices) { device in
                            HStack(spacing: 12) {
                                Image(systemName: "tv")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .font(.headline)
                                    if let model = device.modelName {
                                        Text(model)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Button("Cast") {
                                    onSelectDevice(device)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    HStack {
                        Text("DLNA / UPnP Smart TVs")
                        Spacer()
                        Button(action: {
                            Task {
                                await CastSessionManager.shared.refreshDlnaDevices()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                }

                // Section 3: Manual Direct Connect by IP
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("e.g. 192.168.1.105", text: $manualIpInput)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numbersAndPunctuation)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            if isProbingManualIp {
                                ProgressView()
                                    .padding(.horizontal, 8)
                            } else {
                                Button("Connect") {
                                    connectManualIp()
                                }
                                .buttonStyle(.bordered)
                                .disabled(manualIpInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        if let manualIpError {
                            Text(manualIpError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Direct Connect by TV IP Address")
                } footer: {
                    Text("Check your TV's Network Settings for its IP address if auto-discovery is blocked by router isolation.")
                }
            }
            .navigationTitle("Select TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await CastSessionManager.shared.refreshDlnaDevices()
            }
        }
    }

    private func connectManualIp() {
        let ip = manualIpInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ip.isEmpty else { return }
        isProbingManualIp = true
        manualIpError = nil

        Task {
            if let device = await DlnaDiscovery.shared.probeDevice(at: ip) {
                isProbingManualIp = false
                onSelectDevice(device)
                dismiss()
            } else {
                isProbingManualIp = false
                manualIpError = "Could not reach UPnP service at \(ip). Confirm TV is on."
            }
        }
    }
}
