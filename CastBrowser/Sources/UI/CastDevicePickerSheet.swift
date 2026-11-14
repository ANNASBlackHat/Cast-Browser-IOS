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
    @State private var wifiInfo: WifiNetworkInfo?

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
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scanning Wi-Fi for Smart TVs...")
                                    .font(.subheadline)
                                if let ip = wifiInfo?.ip {
                                    Text("iPad IP: \(ip) (Subnet: \(wifiInfo?.prefix ?? "")...)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } else if CastSessionManager.shared.availableDlnaDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No DLNA TVs Found Automatically")
                                .font(.subheadline.bold())

                            Text("Ensure your TV is turned on and connected to the same Wi-Fi. If iOS prompted for 'Local Network', make sure it is allowed.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 10) {
                                Button(action: {
                                    Task {
                                        await CastSessionManager.shared.deepScanDlnaDevices()
                                    }
                                }) {
                                    Label("Deep Subnet Scan", systemImage: "waveform.and.magnifyingglass")
                                        .font(.caption.bold())
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button(action: {
                                    Task {
                                        await CastSessionManager.shared.refreshDlnaDevices()
                                    }
                                }) {
                                    Label("Rescan", systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 6)
                    } else {
                        ForEach(CastSessionManager.shared.availableDlnaDevices) { device in
                            HStack(spacing: 12) {
                                Image(systemName: "tv")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(device.name)
                                            .font(.headline)
                                        if device.id == SavedDeviceManager.getLastDevice()?.id {
                                            Text("Recently Used")
                                                .font(.caption2.bold())
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.12))
                                                .clipShape(Capsule())
                                        }
                                    }
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
                        if let ip = wifiInfo?.ip {
                            Text("Wi-Fi: \(ip)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
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
                            TextField(wifiInfo?.prefix != nil ? "e.g. \(wifiInfo!.prefix).50" : "e.g. 192.168.1.105", text: $manualIpInput)
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
                                .buttonStyle(.borderedProminent)
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
                    Text("Check your TV's Network Settings for its IP address if discovery is blocked by router isolation or firewall.")
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
                self.wifiInfo = NetworkIpHelper.getWifiNetworkInfo()
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
                SavedDeviceManager.saveDevice(device)
                isProbingManualIp = false
                onSelectDevice(device)
                dismiss()
            } else {
                isProbingManualIp = false
                manualIpError = "Could not reach UPnP service at \(ip). Confirm TV is on and on the same Wi-Fi."
            }
        }
    }
}
