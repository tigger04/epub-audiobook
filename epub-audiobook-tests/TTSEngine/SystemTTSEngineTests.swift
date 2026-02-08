// ABOUTME: Tests for SystemTTSEngine rate mapping, state management, and voice configuration.
// ABOUTME: AVSpeechSynthesizer delegate callbacks require a device; tested via MockTTSEngine.

import XCTest
import AVFoundation
@testable import epub_audiobook

@MainActor
final class SystemTTSEngineTests: XCTestCase {

    private var engine: SystemTTSEngine!

    override func setUp() async throws {
        try await super.setUp()
        engine = SystemTTSEngine()
    }

    override func tearDown() async throws {
        engine?.stop()
        engine = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isIdle() {
        XCTAssertEqual(engine.playbackState, .idle)
    }

    func test_initialRate_isDefault() {
        XCTAssertEqual(engine.rate, 0.5)
    }

    // MARK: - Rate Mapping

    func test_mappedRate_atZero_returnsMinimum() {
        engine.setRate(0.0)
        XCTAssertEqual(engine.mappedRate, AVSpeechUtteranceMinimumSpeechRate, accuracy: 0.001)
    }

    func test_mappedRate_atOne_returnsMaximum() {
        engine.setRate(1.0)
        XCTAssertEqual(engine.mappedRate, AVSpeechUtteranceMaximumSpeechRate, accuracy: 0.001)
    }

    func test_mappedRate_atHalf_returnsMidpoint() {
        engine.setRate(0.5)
        let expected = AVSpeechUtteranceMinimumSpeechRate +
            0.5 * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
        XCTAssertEqual(engine.mappedRate, expected, accuracy: 0.001)
    }

    // MARK: - Rate Clamping

    func test_setRate_clampsNegative() {
        engine.setRate(-1.0)
        XCTAssertEqual(engine.rate, 0.0)
    }

    func test_setRate_clampsAboveOne() {
        engine.setRate(2.0)
        XCTAssertEqual(engine.rate, 1.0)
    }

    // MARK: - Voice

    func test_setVoice_storesIdentifier() {
        engine.setVoice(identifier: "com.apple.voice.compact.en-US.Samantha")
        // No crash, voice is stored for next speak call
    }

    func test_setVoice_nil_clearsIdentifier() {
        engine.setVoice(identifier: "com.apple.voice.compact.en-US.Samantha")
        engine.setVoice(identifier: nil)
        // No crash, falls back to en-US default
    }

    // MARK: - Stop

    func test_stop_whenIdle_remainsIdle() {
        engine.stop()
        XCTAssertEqual(engine.playbackState, .idle)
    }

    // MARK: - Pause / Resume without active speech

    func test_pause_whenIdle_remainsIdle() {
        engine.pause()
        XCTAssertEqual(engine.playbackState, .idle)
    }

    func test_resume_whenIdle_remainsIdle() {
        engine.resume()
        XCTAssertEqual(engine.playbackState, .idle)
    }

    // MARK: - Protocol Conformance

    func test_conformsToProtocol() {
        let protocol_engine: any TTSEngineProtocol = engine
        XCTAssertNotNil(protocol_engine)
    }
}
