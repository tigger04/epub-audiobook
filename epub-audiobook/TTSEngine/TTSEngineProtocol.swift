// ABOUTME: Protocol abstraction for text-to-speech engines.
// ABOUTME: Enables testing with MockTTSEngine and future engine swaps.

import Foundation

/// Represents the current state of TTS playback.
enum PlaybackState: Equatable, Sendable {
    case idle
    case playing
    case paused
    case loading
}

/// A unit of text to be spoken by the TTS engine.
struct Utterance: Equatable, Sendable {
    let text: String
    let identifier: String

    init(text: String, identifier: String = UUID().uuidString) {
        self.text = text
        self.identifier = identifier
    }
}

/// Delegate protocol for receiving TTS engine events.
@MainActor
protocol TTSEngineDelegate: AnyObject {
    func ttsEngine(_ engine: any TTSEngineProtocol, didStartUtterance utterance: Utterance)
    func ttsEngine(_ engine: any TTSEngineProtocol, didFinishUtterance utterance: Utterance)
    func ttsEngine(_ engine: any TTSEngineProtocol, didReachWordRange range: Range<String.Index>, in utterance: Utterance)
    func ttsEngine(_ engine: any TTSEngineProtocol, didEncounterError error: Error)
}

/// Protocol for TTS engine implementations.
@MainActor
protocol TTSEngineProtocol: AnyObject {
    var delegate: (any TTSEngineDelegate)? { get set }
    var playbackState: PlaybackState { get }
    var rate: Float { get }

    func speak(_ utterance: Utterance)
    func pause()
    func resume()
    func stop()
    func setRate(_ rate: Float)
}
