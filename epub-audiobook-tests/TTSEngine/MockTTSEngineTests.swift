// ABOUTME: Tests for MockTTSEngine verifying protocol conformance and delegate callbacks.
// ABOUTME: Validates playback state transitions, rate control, and error handling.

import XCTest
@testable import epub_audiobook

@MainActor
final class MockTTSEngineTests: XCTestCase {

    private var engine: MockTTSEngine!
    private var delegateRecorder: DelegateRecorder!

    override func setUp() async throws {
        try await super.setUp()
        engine = MockTTSEngine()
        delegateRecorder = DelegateRecorder()
        engine.delegate = delegateRecorder
    }

    override func tearDown() async throws {
        engine = nil
        delegateRecorder = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isIdle() {
        XCTAssertEqual(engine.playbackState, .idle)
        XCTAssertEqual(engine.rate, 0.5)
        XCTAssertTrue(engine.spokenUtterances.isEmpty)
    }

    // MARK: - Speak

    func test_speak_firesDidStart() {
        // Arrange
        let utterance = Utterance(text: "Hello world", identifier: "u1")

        // Act
        engine.speak(utterance)

        // Assert
        XCTAssertEqual(delegateRecorder.startedUtterances.count, 1)
        XCTAssertEqual(delegateRecorder.startedUtterances.first?.identifier, "u1")
    }

    func test_speak_autoFinish_firesDidFinish() {
        // Arrange
        engine.autoFinish = true
        let utterance = Utterance(text: "Hello", identifier: "u1")

        // Act
        engine.speak(utterance)

        // Assert
        XCTAssertEqual(delegateRecorder.finishedUtterances.count, 1)
        XCTAssertEqual(delegateRecorder.finishedUtterances.first?.identifier, "u1")
        XCTAssertEqual(engine.playbackState, .idle)
    }

    func test_speak_noAutoFinish_remainsPlaying() {
        // Arrange
        engine.autoFinish = false
        let utterance = Utterance(text: "Hello", identifier: "u1")

        // Act
        engine.speak(utterance)

        // Assert
        XCTAssertEqual(engine.playbackState, .playing)
        XCTAssertTrue(delegateRecorder.finishedUtterances.isEmpty)
    }

    func test_speak_recordsUtterance() {
        // Arrange
        let u1 = Utterance(text: "First", identifier: "u1")
        let u2 = Utterance(text: "Second", identifier: "u2")

        // Act
        engine.speak(u1)
        engine.speak(u2)

        // Assert
        XCTAssertEqual(engine.spokenUtterances.count, 2)
        XCTAssertEqual(engine.spokenUtterances[0].text, "First")
        XCTAssertEqual(engine.spokenUtterances[1].text, "Second")
    }

    // MARK: - Pause / Resume

    func test_pause_whenPlaying_transitionsToPaused() {
        // Arrange
        engine.autoFinish = false
        engine.speak(Utterance(text: "Hello", identifier: "u1"))

        // Act
        engine.pause()

        // Assert
        XCTAssertEqual(engine.playbackState, .paused)
    }

    func test_pause_whenIdle_remainsIdle() {
        engine.pause()
        XCTAssertEqual(engine.playbackState, .idle)
    }

    func test_resume_whenPaused_transitionsToPlaying() {
        // Arrange
        engine.autoFinish = false
        engine.speak(Utterance(text: "Hello", identifier: "u1"))
        engine.pause()

        // Act
        engine.resume()

        // Assert
        XCTAssertEqual(engine.playbackState, .playing)
    }

    func test_resume_whenIdle_remainsIdle() {
        engine.resume()
        XCTAssertEqual(engine.playbackState, .idle)
    }

    // MARK: - Stop

    func test_stop_whenPlaying_transitionsToIdleAndFiresFinish() {
        // Arrange
        engine.autoFinish = false
        engine.speak(Utterance(text: "Hello", identifier: "u1"))

        // Act
        engine.stop()

        // Assert
        XCTAssertEqual(engine.playbackState, .idle)
        XCTAssertEqual(delegateRecorder.finishedUtterances.count, 1)
    }

    func test_stop_whenIdle_remainsIdle() {
        engine.stop()
        XCTAssertEqual(engine.playbackState, .idle)
        XCTAssertTrue(delegateRecorder.finishedUtterances.isEmpty)
    }

    // MARK: - Rate

    func test_setRate_clampsToValidRange() {
        engine.setRate(0.0)
        XCTAssertEqual(engine.rate, 0.0)

        engine.setRate(1.0)
        XCTAssertEqual(engine.rate, 1.0)

        engine.setRate(-0.5)
        XCTAssertEqual(engine.rate, 0.0)

        engine.setRate(1.5)
        XCTAssertEqual(engine.rate, 1.0)
    }

    func test_setRate_acceptsMiddleValue() {
        engine.setRate(0.75)
        XCTAssertEqual(engine.rate, 0.75)
    }

    // MARK: - Word Range

    func test_simulateWordRange_firesDelegate() {
        // Arrange
        let utterance = Utterance(text: "Hello world", identifier: "u1")
        let range = utterance.text.startIndex..<utterance.text.index(utterance.text.startIndex, offsetBy: 5)

        // Act
        engine.simulateWordRange(range, in: utterance)

        // Assert
        XCTAssertEqual(delegateRecorder.wordRanges.count, 1)
    }

    // MARK: - Error

    func test_simulateError_firesDelegate() {
        // Arrange
        let error = NSError(domain: "test", code: 42)

        // Act
        engine.simulateError(error)

        // Assert
        XCTAssertEqual(engine.playbackState, .idle)
        XCTAssertEqual(delegateRecorder.errors.count, 1)
        XCTAssertEqual((delegateRecorder.errors.first as? NSError)?.code, 42)
    }

    // MARK: - Manual Finish

    func test_finishCurrentUtterance_completesManually() {
        // Arrange
        engine.autoFinish = false
        engine.speak(Utterance(text: "Hello", identifier: "u1"))
        XCTAssertEqual(engine.playbackState, .playing)

        // Act
        engine.finishCurrentUtterance()

        // Assert
        XCTAssertEqual(engine.playbackState, .idle)
        XCTAssertEqual(delegateRecorder.finishedUtterances.count, 1)
    }
}

// MARK: - Test Helper

@MainActor
private final class DelegateRecorder: TTSEngineDelegate {
    var startedUtterances: [Utterance] = []
    var finishedUtterances: [Utterance] = []
    var wordRanges: [(Range<String.Index>, Utterance)] = []
    var errors: [Error] = []

    func ttsEngine(_ engine: any TTSEngineProtocol, didStartUtterance utterance: Utterance) {
        startedUtterances.append(utterance)
    }

    func ttsEngine(_ engine: any TTSEngineProtocol, didFinishUtterance utterance: Utterance) {
        finishedUtterances.append(utterance)
    }

    func ttsEngine(_ engine: any TTSEngineProtocol, didReachWordRange range: Range<String.Index>, in utterance: Utterance) {
        wordRanges.append((range, utterance))
    }

    func ttsEngine(_ engine: any TTSEngineProtocol, didEncounterError error: Error) {
        errors.append(error)
    }
}
