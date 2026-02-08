// ABOUTME: Manages MPNowPlayingInfoCenter and MPRemoteCommandCenter integration.
// ABOUTME: Displays book info on lock screen and handles remote playback commands.

import Foundation
import MediaPlayer

/// Manages Now Playing info and remote command handlers for lock screen / Control Centre.
@MainActor
final class NowPlayingService {

    private let coordinator: PlaybackCoordinator
    private var isConfigured = false

    init(coordinator: PlaybackCoordinator) {
        self.coordinator = coordinator
    }

    /// Configure remote commands (call once).
    func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.coordinator.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.coordinator.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.coordinator.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.coordinator.skipForward()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.coordinator.skipBackward()
            return .success
        }

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
    }

    /// Update the Now Playing info display.
    func updateNowPlayingInfo(
        bookTitle: String,
        chapterTitle: String,
        chapterIndex: Int,
        totalChapters: Int,
        coverImageData: Data?
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: chapterTitle,
            MPMediaItemPropertyAlbumTitle: bookTitle,
            MPMediaItemPropertyAlbumTrackNumber: chapterIndex + 1,
            MPMediaItemPropertyAlbumTrackCount: totalChapters,
            MPNowPlayingInfoPropertyPlaybackRate: coordinator.playbackState == .playing ? 1.0 : 0.0,
        ]

        if let data = coverImageData, let image = UIImage(data: data) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Clear Now Playing info when playback stops.
    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
