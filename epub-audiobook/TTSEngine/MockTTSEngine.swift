// ABOUTME: Mock TTS engine for testing playback coordinator and other components.
// ABOUTME: Simulates speech lifecycle with synchronous delegate callbacks.

import Foundation

/// Mock TTS engine that simulates speech without actual audio output.
@MainActor
final class MockTTSEngine: TTSEngineProtocol {
    weak var delegate: (any TTSEngineDelegate)?
    private(set) var playbackState: PlaybackState = .idle
    private(set) var rate: Float = 0.5

    private(set) var spokenUtterances: [Utterance] = []
    private var currentUtterance: Utterance?

    /// When true, immediately fires didFinish after didStart for each utterance.
    var autoFinish: Bool = true

    func speak(_ utterance: Utterance) {
        spokenUtterances.append(utterance)
        currentUtterance = utterance
        playbackState = .playing
        delegate?.ttsEngine(self, didStartUtterance: utterance)

        if autoFinish {
            finishCurrentUtterance()
        }
    }

    func pause() {
        guard playbackState == .playing else { return }
        playbackState = .paused
    }

    func resume() {
        guard playbackState == .paused else { return }
        playbackState = .playing
    }

    func stop() {
        if let utterance = currentUtterance {
            playbackState = .idle
            currentUtterance = nil
            delegate?.ttsEngine(self, didFinishUtterance: utterance)
        } else {
            playbackState = .idle
        }
    }

    func setRate(_ rate: Float) {
        self.rate = max(0.0, min(1.0, rate))
    }

    /// Manually finish the current utterance (for when autoFinish is false).
    func finishCurrentUtterance() {
        guard let utterance = currentUtterance else { return }
        currentUtterance = nil
        playbackState = .idle
        delegate?.ttsEngine(self, didFinishUtterance: utterance)
    }

    /// Simulate a word range being reached during speech.
    func simulateWordRange(_ range: Range<String.Index>, in utterance: Utterance) {
        delegate?.ttsEngine(self, didReachWordRange: range, in: utterance)
    }

    /// Simulate an error during speech.
    func simulateError(_ error: Error) {
        playbackState = .idle
        currentUtterance = nil
        delegate?.ttsEngine(self, didEncounterError: error)
    }
}
