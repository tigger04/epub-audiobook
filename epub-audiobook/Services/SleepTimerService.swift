// ABOUTME: Sleep timer that stops playback after a set duration or at end of chapter.
// ABOUTME: Provides countdown display and cancellation.

import Foundation
import Observation

/// Sleep timer options.
enum SleepTimerOption: Equatable, Sendable {
    case minutes(Int)
    case endOfChapter
}

/// Manages a sleep timer for automatic playback stop.
@MainActor
@Observable
final class SleepTimerService {

    private(set) var isActive = false
    private(set) var remainingSeconds: Int = 0
    private(set) var option: SleepTimerOption?

    private let coordinator: PlaybackCoordinator
    private var timer: Timer?
    private var initialChapterIndex: Int?

    init(coordinator: PlaybackCoordinator) {
        self.coordinator = coordinator
    }

    /// Start a sleep timer with the given option.
    func start(option: SleepTimerOption) {
        cancel()
        self.option = option
        isActive = true

        switch option {
        case .minutes(let minutes):
            remainingSeconds = minutes * 60
            startCountdown()
        case .endOfChapter:
            initialChapterIndex = coordinator.currentChapterIndex
            remainingSeconds = 0
            startChapterWatch()
        }
    }

    /// Cancel the active sleep timer.
    func cancel() {
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingSeconds = 0
        option = nil
        initialChapterIndex = nil
    }

    /// Formatted time remaining string.
    var formattedRemaining: String {
        guard isActive else { return "" }
        if case .endOfChapter = option {
            return "End of chapter"
        }
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Private

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.remainingSeconds -= 1
                if self.remainingSeconds <= 0 {
                    self.coordinator.stop()
                    self.cancel()
                }
            }
        }
    }

    private func startChapterWatch() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.coordinator.currentChapterIndex != self.initialChapterIndex ||
                   self.coordinator.playbackState == .idle {
                    self.coordinator.stop()
                    self.cancel()
                }
            }
        }
    }
}
