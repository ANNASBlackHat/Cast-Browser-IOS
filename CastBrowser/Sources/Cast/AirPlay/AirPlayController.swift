//
//  AirPlayController.swift
//  CastBrowser
//

import Foundation
import AVFoundation
import MediaPlayer

@MainActor
public protocol AirPlayControllerDelegate: AnyObject {
    func airPlayPlaybackStateChanged(_ state: CastPlaybackState)
}

@MainActor
public final class AirPlayController: NSObject {
    public weak var delegate: AirPlayControllerDelegate?

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var currentTitle: String = ""
    private var currentStreamUrl: URL?

    public override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            print("[AirPlayController] Audio session configuration failed: \(error)")
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player else { return .commandFailed }
            if player.timeControlStatus == .playing {
                self.pause()
            } else {
                self.play()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }

    public func startPlayback(url: URL, title: String, startPosition: Double = 0.0) {
        self.currentTitle = title
        self.currentStreamUrl = url

        // Clean up any existing player
        stop()

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        self.player = player

        // Attach periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let current = CMTimeGetSeconds(time)
            let duration = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
            let validDuration = duration.isFinite && duration > 0 ? duration : 0.0

            let isPlaying = player.timeControlStatus == .playing
            let status: CastPlaybackStatus = isPlaying ? .playing : (player.timeControlStatus == .waitingToPlayAtSpecifiedRate ? .buffering : .paused)

            let state = CastPlaybackState(
                status: status,
                positionSeconds: current,
                durationSeconds: validDuration
            )
            self.delegate?.airPlayPlaybackStateChanged(state)
            self.updateNowPlaying(position: current, duration: validDuration, isPlaying: isPlaying)
        }

        if startPosition > 0 {
            seek(to: startPosition)
        }
        player.play()
    }

    public func play() {
        player?.play()
    }

    public func pause() {
        player?.pause()
    }

    public func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func stop() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        delegate?.airPlayPlaybackStateChanged(CastPlaybackState(status: .stopped))
    }

    private func updateNowPlaying(position: Double, duration: Double, isPlaying: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
