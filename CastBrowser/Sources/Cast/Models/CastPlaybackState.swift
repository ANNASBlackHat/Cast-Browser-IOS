//
//  CastPlaybackState.swift
//  CastBrowser
//

import Foundation

public enum CastPlaybackStatus: String, Sendable {
    case idle
    case connecting
    case playing
    case paused
    case buffering
    case stopped
    case failed
}

public struct CastPlaybackState: Equatable, Sendable {
    public var status: CastPlaybackStatus
    public var positionSeconds: Double
    public var durationSeconds: Double
    public var isMuted: Bool
    public var volume: Float

    public init(
        status: CastPlaybackStatus = .idle,
        positionSeconds: Double = 0.0,
        durationSeconds: Double = 0.0,
        isMuted: Bool = false,
        volume: Float = 1.0
    ) {
        self.status = status
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
        self.isMuted = isMuted
        self.volume = volume
    }

    public var progress: Double {
        guard durationSeconds > 0 else { return 0.0 }
        return min(max(positionSeconds / durationSeconds, 0.0), 1.0)
    }
}
