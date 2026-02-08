// ABOUTME: Playback control buttons: skip backward, play/pause, skip forward, stop.
// ABOUTME: Uses SF Symbols and communicates via PlaybackCoordinator.

import SwiftUI

struct PlaybackControlsView: View {
    let coordinator: PlaybackCoordinator

    var body: some View {
        HStack(spacing: 32) {
            Button {
                coordinator.skipBackward()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Skip backward")

            Button {
                coordinator.togglePlayPause()
            } label: {
                Image(systemName: playPauseIcon)
                    .font(.system(size: 44))
            }
            .accessibilityLabel(coordinator.playbackState == .playing ? "Pause" : "Play")

            Button {
                coordinator.skipForward()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Skip forward")

            Button {
                coordinator.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Stop")
        }
        .buttonStyle(.plain)
    }

    private var playPauseIcon: String {
        coordinator.playbackState == .playing ? "pause.circle.fill" : "play.circle.fill"
    }
}
