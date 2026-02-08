// ABOUTME: Tests for PlaybackCoordinator using MockTTSEngine.
// ABOUTME: Verifies playback state transitions, chapter navigation, and position persistence.

import XCTest
import SwiftData
@testable import epub_audiobook

@MainActor
final class PlaybackCoordinatorTests: XCTestCase {

    private var engine: MockTTSEngine!
    private var container: ModelContainer!
    private var context: ModelContext!
    private var coordinator: PlaybackCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        engine = MockTTSEngine()
        engine.autoFinish = false
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Book.self, Chapter.self, ReadingPosition.self, Bookmark.self,
            configurations: config
        )
        context = container.mainContext
        coordinator = PlaybackCoordinator(ttsEngine: engine, modelContext: context)
    }

    override func tearDown() async throws {
        coordinator = nil
        engine = nil
        container = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func createBook(
        title: String = "Test Book",
        chapters: [(String, [String])] = [
            ("Chapter 1", ["Sentence one.", "Sentence two.", "Sentence three."]),
            ("Chapter 2", ["Another sentence.", "Final sentence."]),
        ]
    ) -> Book {
        let book = Book(title: title, epubFilePath: "/test.epub")
        context.insert(book)
        for (index, (chTitle, sentences)) in chapters.enumerated() {
            let chapter = Chapter(title: chTitle, sentences: sentences, spineIndex: index, book: book)
            context.insert(chapter)
        }
        let position = ReadingPosition(chapterIndex: 0, sentenceIndex: 0, book: book)
        context.insert(position)
        try? context.save()
        return book
    }

    // MARK: - Initial State

    func test_initialState_isIdle() {
        XCTAssertEqual(coordinator.playbackState, .idle)
        XCTAssertEqual(coordinator.currentChapterIndex, 0)
        XCTAssertEqual(coordinator.currentSentenceIndex, 0)
    }

    // MARK: - Load Book

    func test_loadBook_setsChaptersAndPosition() {
        let book = createBook()
        coordinator.loadBook(book)
        XCTAssertNotNil(coordinator.currentChapter)
        XCTAssertEqual(coordinator.currentChapter?.title, "Chapter 1")
    }

    func test_loadBook_resumesFromSavedPosition() {
        let book = createBook()
        book.readingPosition?.chapterIndex = 1
        book.readingPosition?.sentenceIndex = 1
        try? context.save()

        coordinator.loadBook(book)
        XCTAssertEqual(coordinator.currentChapterIndex, 1)
        XCTAssertEqual(coordinator.currentSentenceIndex, 1)
    }

    // MARK: - Play

    func test_play_transitionsToPlaying() {
        let book = createBook()
        coordinator.loadBook(book)

        coordinator.play()

        XCTAssertEqual(coordinator.playbackState, .playing)
        XCTAssertEqual(engine.spokenUtterances.count, 1)
        XCTAssertEqual(engine.spokenUtterances.first?.text, "Sentence one.")
    }

    func test_play_withNoBook_doesNothing() {
        coordinator.play()
        XCTAssertEqual(coordinator.playbackState, .idle)
    }

    // MARK: - Pause / Resume

    func test_pause_transitionsToPaused() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.play()

        coordinator.pause()

        XCTAssertEqual(coordinator.playbackState, .paused)
    }

    func test_resume_fromPaused_transitionsToPlaying() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.play()
        coordinator.pause()

        coordinator.play()

        XCTAssertEqual(coordinator.playbackState, .playing)
    }

    // MARK: - Stop

    func test_stop_transitionsToIdle() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.play()

        coordinator.stop()

        XCTAssertEqual(coordinator.playbackState, .idle)
    }

    // MARK: - Toggle

    func test_togglePlayPause_fromIdle_plays() {
        let book = createBook()
        coordinator.loadBook(book)

        coordinator.togglePlayPause()

        XCTAssertEqual(coordinator.playbackState, .playing)
    }

    func test_togglePlayPause_fromPlaying_pauses() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.play()

        coordinator.togglePlayPause()

        XCTAssertEqual(coordinator.playbackState, .paused)
    }

    // MARK: - Sentence Advancement

    func test_didFinishUtterance_advancesToNextSentence() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.play()

        // Finish first sentence → should auto-advance
        engine.finishCurrentUtterance()

        XCTAssertEqual(coordinator.currentSentenceIndex, 1)
        XCTAssertEqual(engine.spokenUtterances.count, 2)
        XCTAssertEqual(engine.spokenUtterances.last?.text, "Sentence two.")
    }

    // MARK: - Chapter Transition

    func test_didFinishLastSentence_advancesToNextChapter() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.play()

        // Finish all 3 sentences of chapter 1
        engine.finishCurrentUtterance() // sentence 0 → 1
        engine.finishCurrentUtterance() // sentence 1 → 2
        engine.finishCurrentUtterance() // sentence 2 → chapter 2, sentence 0

        XCTAssertEqual(coordinator.currentChapterIndex, 1)
        XCTAssertEqual(coordinator.currentSentenceIndex, 0)
        XCTAssertEqual(engine.spokenUtterances.last?.text, "Another sentence.")
    }

    func test_didFinishLastChapter_stopsPlayback() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.play()

        // Finish all sentences in both chapters
        engine.finishCurrentUtterance() // ch1 s0→s1
        engine.finishCurrentUtterance() // ch1 s1→s2
        engine.finishCurrentUtterance() // ch1 s2→ch2 s0
        engine.finishCurrentUtterance() // ch2 s0→s1
        engine.finishCurrentUtterance() // ch2 s1→end

        XCTAssertEqual(coordinator.playbackState, .idle)
    }

    // MARK: - Skip Forward / Backward

    func test_skipForward_advancesSentence() {
        let book = createBook()
        coordinator.loadBook(book)

        coordinator.skipForward()

        XCTAssertEqual(coordinator.currentSentenceIndex, 1)
    }

    func test_skipForward_atChapterEnd_advancesChapter() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.skipForward() // s0→s1
        coordinator.skipForward() // s1→s2
        coordinator.skipForward() // s2→ch2 s0

        XCTAssertEqual(coordinator.currentChapterIndex, 1)
        XCTAssertEqual(coordinator.currentSentenceIndex, 0)
    }

    func test_skipForward_atBookEnd_staysAtEnd() {
        let book = createBook(chapters: [("Ch1", ["Only sentence."])])
        coordinator.loadBook(book)

        coordinator.skipForward()

        XCTAssertEqual(coordinator.currentChapterIndex, 0)
        XCTAssertEqual(coordinator.currentSentenceIndex, 0)
    }

    func test_skipBackward_decrementsSentence() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.skipForward() // move to s1

        coordinator.skipBackward()

        XCTAssertEqual(coordinator.currentSentenceIndex, 0)
    }

    func test_skipBackward_atChapterStart_goesToPreviousChapter() {
        let book = createBook()
        coordinator.loadBook(book)
        // Navigate to chapter 2
        coordinator.jumpToChapter(1)

        coordinator.skipBackward()

        XCTAssertEqual(coordinator.currentChapterIndex, 0)
        XCTAssertEqual(coordinator.currentSentenceIndex, 2) // last sentence of ch1
    }

    func test_skipBackward_atBookStart_staysAtStart() {
        let book = createBook()
        coordinator.loadBook(book)

        coordinator.skipBackward()

        XCTAssertEqual(coordinator.currentChapterIndex, 0)
        XCTAssertEqual(coordinator.currentSentenceIndex, 0)
    }

    // MARK: - Jump To Chapter

    func test_jumpToChapter_setsCorrectPosition() {
        let book = createBook()
        coordinator.loadBook(book)

        coordinator.jumpToChapter(1)

        XCTAssertEqual(coordinator.currentChapterIndex, 1)
        XCTAssertEqual(coordinator.currentSentenceIndex, 0)
    }

    func test_jumpToChapter_invalidIndex_doesNothing() {
        let book = createBook()
        coordinator.loadBook(book)

        coordinator.jumpToChapter(99)

        XCTAssertEqual(coordinator.currentChapterIndex, 0)
    }

    // MARK: - Progress

    func test_chapterProgress_atStart_isZero() {
        let book = createBook()
        coordinator.loadBook(book)
        XCTAssertEqual(coordinator.chapterProgress, 0.0, accuracy: 0.01)
    }

    func test_bookProgress_midway_isCorrect() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.jumpToChapter(1) // ch2 has 2 sentences, ch1 had 3
        // 3 sentences before + 0 current = 3/5 = 0.6
        XCTAssertEqual(coordinator.bookProgress, 0.6, accuracy: 0.01)
    }

    // MARK: - Position Persistence

    func test_pause_persistsPosition() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.play()
        engine.finishCurrentUtterance() // advance to sentence 1
        coordinator.pause()

        XCTAssertEqual(book.readingPosition?.sentenceIndex, 1)
    }

    func test_stop_persistsPosition() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.play()
        // finishCurrentUtterance: s0 done → advance to s1, speak it
        engine.finishCurrentUtterance()
        // Now at ch0 s1, playing
        coordinator.stop()

        XCTAssertEqual(book.readingPosition?.chapterIndex, 0)
        XCTAssertEqual(book.readingPosition?.sentenceIndex, 1)
    }

    // MARK: - Word Range

    func test_didReachWordRange_updatesCurrentWordRange() {
        let book = createBook()
        coordinator.loadBook(book)
        coordinator.play()

        let text = "Sentence one."
        let range = text.startIndex..<text.index(text.startIndex, offsetBy: 8)
        let utterance = Utterance(text: text, identifier: "0-0")
        engine.simulateWordRange(range, in: utterance)

        XCTAssertNotNil(coordinator.currentWordRange)
    }
}
