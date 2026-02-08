// ABOUTME: AVSpeechSynthesizer wrapper implementing TTSEngineProtocol.
// ABOUTME: Handles iOS 17 workarounds: long-lived instance, sentence-level utterances, rate mapping.

import AVFoundation

/// Concrete TTS engine using AVSpeechSynthesizer.
@MainActor
final class SystemTTSEngine: NSObject, TTSEngineProtocol {
    weak var delegate: (any TTSEngineDelegate)?
    private(set) var playbackState: PlaybackState = .idle
    private(set) var rate: Float = 0.5

    private let synthesizer: AVSpeechSynthesizer
    private var currentUtterance: Utterance?
    private var utteranceMap: [AVSpeechUtterance: Utterance] = [:]
    private var voiceIdentifier: String?

    override init() {
        synthesizer = AVSpeechSynthesizer()
        super.init()
        synthesizer.delegate = self
        observeInterruptions()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            // Interruption handling is done in the notification — for simplicity
            // we just pause on any interruption from the main queue callback.
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.playbackState == .playing {
                    self.pause()
                }
            }
        }
    }

    func speak(_ utterance: Utterance) {
        configureAudioSession()

        let avUtterance = AVSpeechUtterance(string: utterance.text)
        avUtterance.rate = mappedRate
        avUtterance.pitchMultiplier = 1.0

        if let voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            avUtterance.voice = voice
        } else {
            avUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        utteranceMap[avUtterance] = utterance
        currentUtterance = utterance
        playbackState = .playing

        synthesizer.speak(avUtterance)
    }

    func pause() {
        guard playbackState == .playing else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        playbackState = .paused
    }

    func resume() {
        guard playbackState == .paused else { return }
        synthesizer.continueSpeaking()
        playbackState = .playing
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        playbackState = .idle
        currentUtterance = nil
    }

    func setRate(_ rate: Float) {
        self.rate = max(0.0, min(1.0, rate))
    }

    /// Set the voice by BCP 47 language tag or voice identifier.
    func setVoice(identifier: String?) {
        self.voiceIdentifier = identifier
    }

    // MARK: - Rate Mapping

    /// Maps abstract 0.0–1.0 rate to AVSpeechUtterance rate range.
    var mappedRate: Float {
        let minRate = AVSpeechUtteranceMinimumSpeechRate
        let maxRate = AVSpeechUtteranceMaximumSpeechRate
        return minRate + (rate * (maxRate - minRate))
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            delegate?.ttsEngine(self, didEncounterError: error)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
// AVSpeechSynthesizerDelegate callbacks are delivered on the main thread.

extension SystemTTSEngine: @preconcurrency AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard let mapped = utteranceMap[utterance] else { return }
        delegate?.ttsEngine(self, didStartUtterance: mapped)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let mapped = utteranceMap.removeValue(forKey: utterance) else { return }
        if currentUtterance?.identifier == mapped.identifier {
            currentUtterance = nil
            playbackState = .idle
        }
        delegate?.ttsEngine(self, didFinishUtterance: mapped)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if let mapped = utteranceMap.removeValue(forKey: utterance) {
            if currentUtterance?.identifier == mapped.identifier {
                currentUtterance = nil
                playbackState = .idle
            }
            delegate?.ttsEngine(self, didFinishUtterance: mapped)
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        guard let mapped = utteranceMap[utterance] else { return }
        let text = mapped.text
        guard let range = Range(characterRange, in: text) else { return }
        delegate?.ttsEngine(self, didReachWordRange: range, in: mapped)
    }
}
