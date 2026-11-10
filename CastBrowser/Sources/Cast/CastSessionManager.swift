//
//  CastSessionManager.swift
//  CastBrowser
//

import Foundation
import SwiftUI
import WebKit

@Observable
@MainActor
public final class CastSessionManager: AirPlayControllerDelegate {
    public static let shared = CastSessionManager()

    public var activeDevice: CastDevice?
    public var playbackState: CastPlaybackState = CastPlaybackState()
    public var currentMediaTitle: String = ""
    public var currentStreamUrl: URL?
    public var availableDlnaDevices: [CastDevice] = []
    public var isDiscoveringDevices: Bool = false

    private let airPlayController = AirPlayController()
    private var repository: DataRepository?
    private var currentPageUrl: String = ""

    private init() {
        airPlayController.delegate = self
    }

    public func setRepository(_ repo: DataRepository) {
        self.repository = repo
    }

    public func refreshDlnaDevices() async {
        self.isDiscoveringDevices = true
        let dlnaDevices = await DlnaDiscovery.shared.discoverDevices(timeoutSeconds: 3.0)
        self.availableDlnaDevices = dlnaDevices
        self.isDiscoveringDevices = false
    }

    public func cast(
        stream: DetectedStream,
        to device: CastDevice? = nil,
        pageUrl: URL? = nil,
        cookies: [HTTPCookie] = []
    ) async {
        self.currentMediaTitle = stream.title
        self.currentStreamUrl = stream.url
        self.currentPageUrl = pageUrl?.absoluteString ?? stream.pageUrl.absoluteString
        self.playbackState.status = .connecting

        // Ensure local proxy server is active
        await LocalHttpServer.shared.start()

        // Format cookie string if any
        let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")

        // Register stream with local proxy
        let (_, proxyUrl) = await ProxyStreamManager.shared.registerSession(
            streamUrl: stream.url,
            referer: pageUrl ?? stream.pageUrl,
            cookies: cookieHeader.isEmpty ? nil : cookieHeader
        )

        // Route: If explicit DLNA device chosen -> use DLNA controller; otherwise route to AirPlay
        if let device, device.protocolType == .dlna {
            self.activeDevice = device
            let success = await DlnaController.shared.setAvTransportUri(
                device: device,
                streamUrl: proxyUrl,
                title: stream.title
            )
            if success {
                self.playbackState.status = .playing
            } else {
                self.playbackState.status = .failed
            }
        } else {
            // Default to AirPlay 2
            let airplayDevice = CastDevice(
                id: "airplay-default",
                name: "AirPlay 2 Speaker / TV",
                protocolType: .airplay
            )
            self.activeDevice = airplayDevice
            airPlayController.startPlayback(url: proxyUrl, title: stream.title)
        }
    }

    public func play() {
        if let device = activeDevice, device.protocolType == .dlna {
            Task {
                _ = await DlnaController.shared.play(device: device)
                self.playbackState.status = .playing
            }
        } else {
            airPlayController.play()
        }
    }

    public func pause() {
        if let device = activeDevice, device.protocolType == .dlna {
            Task {
                _ = await DlnaController.shared.pause(device: device)
                self.playbackState.status = .paused
            }
        } else {
            airPlayController.pause()
        }
    }

    public func seek(to seconds: Double) {
        if let device = activeDevice, device.protocolType == .dlna {
            Task {
                _ = await DlnaController.shared.seek(device: device, to: seconds)
                self.playbackState.positionSeconds = seconds
            }
        } else {
            airPlayController.seek(to: seconds)
        }
    }

    public func stop() {
        if let device = activeDevice, device.protocolType == .dlna {
            Task {
                _ = await DlnaController.shared.stop(device: device)
            }
        } else {
            airPlayController.stop()
        }
        self.activeDevice = nil
        self.playbackState.status = .stopped
    }

    // MARK: - AirPlayControllerDelegate

    public func airPlayPlaybackStateChanged(_ state: CastPlaybackState) {
        self.playbackState = state

        // Sync watch progress to database
        if state.positionSeconds > 5.0 && !currentPageUrl.isEmpty {
            repository?.saveWatchProgress(
                pageUrl: currentPageUrl,
                streamUrl: currentStreamUrl?.absoluteString ?? "",
                rawTitle: currentMediaTitle,
                positionSeconds: state.positionSeconds,
                durationSeconds: state.durationSeconds
            )
        }
    }
}
