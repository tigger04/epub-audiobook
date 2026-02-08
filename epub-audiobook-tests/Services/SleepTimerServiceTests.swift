// ABOUTME: Tests for SleepTimerService activation, cancellation, and formatting.
// ABOUTME: Uses MockTTSEngine via PlaybackCoordinator.

import XCTest
@testable import epub_audiobook

@MainActor
final class SleepTimerServiceTests: XCTestCase {

    private var engine: MockTTSEngine!
    private var coordinator: PlaybackCoordinator!
    private var timerService: SleepTimerService!

    override func setUp() async throws {
        try await super.setUp()
        engine = MockTTSEngine()
        engine.autoFinish = false
        coordinator = PlaybackCoordinator(ttsEngine: engine)
        timerService = SleepTimerService(coordinator: coordinator)
    }

    override func tearDown() async throws {
        timerService?.cancel()
        timerService = nil
        coordinator = nil
        engine = nil
        try await super.tearDown()
    }

    func test_initialState_isInactive() {
        XCTAssertFalse(timerService.isActive)
        XCTAssertEqual(timerService.remainingSeconds, 0)
        XCTAssertNil(timerService.option)
    }

    func test_start_minutes_activatesTimer() {
        timerService.start(option: .minutes(15))

        XCTAssertTrue(timerService.isActive)
        XCTAssertEqual(timerService.remainingSeconds, 900)
        XCTAssertEqual(timerService.option, .minutes(15))
    }

    func test_start_endOfChapter_activatesTimer() {
        timerService.start(option: .endOfChapter)

        XCTAssertTrue(timerService.isActive)
        XCTAssertEqual(timerService.option, .endOfChapter)
    }

    func test_cancel_deactivatesTimer() {
        timerService.start(option: .minutes(30))
        timerService.cancel()

        XCTAssertFalse(timerService.isActive)
        XCTAssertEqual(timerService.remainingSeconds, 0)
        XCTAssertNil(timerService.option)
    }

    func test_formattedRemaining_returnsCorrectFormat() {
        timerService.start(option: .minutes(15))
        XCTAssertEqual(timerService.formattedRemaining, "15:00")
    }

    func test_formattedRemaining_endOfChapter_returnsLabel() {
        timerService.start(option: .endOfChapter)
        XCTAssertEqual(timerService.formattedRemaining, "End of chapter")
    }

    func test_formattedRemaining_inactive_returnsEmpty() {
        XCTAssertEqual(timerService.formattedRemaining, "")
    }
}
