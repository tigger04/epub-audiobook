// ABOUTME: Central coordinator for TTS playback, managing chapter transitions and reading position.
// ABOUTME: Feeds sentences one at a time to the TTS engine, advancing chapters automatically.

import Foundation
import SwiftData
import Observation

/// Orchestrates TTS playback across chapters and persists reading position.
@MainActor
@Observable
final class PlaybackCoordinator: TTSEngineDelegate {

    // MARK: - Published State

    private(set) var playbackState: PlaybackState = .idle
    private(set) var currentChapterIndex: Int = 0
    private(set) var currentSentenceIndex: Int = 0
    private(set) var currentWordRange: Range<String.Index>?
    private(set) var rate: Float = 0.5

    // MARK: - Dependencies

    private let ttsEngine: any TTSEngineProtocol
    private let modelContext: ModelContext?

    // MARK: - Internal State

    private var book: Book?
    private var chapters: [Chapter] = []

    var currentChapter: Chapter? {
        guard currentChapterIndex < chapters.count else { return nil }
        return chapters[currentChapterIndex]
    }

    var currentSentenceText: String? {
        guard let chapter = currentChapter,
              currentSentenceIndex < chapter.sentences.count else { return nil }
        return chapter.sentences[currentSentenceIndex]
    }

    /// Progress through the current chapter (0.0–1.0).
    var chapterProgress: Double {
        guard let chapter = currentChapter, !chapter.sentences.isEmpty else { return 0 }
        return Double(currentSentenceIndex) / Double(chapter.sentences.count)
    }

    /// Progress through the entire book (0.0–1.0).
    var bookProgress: Double {
        guard !chapters.isEmpty else { return 0 }
        let totalSentences = chapters.reduce(0) { $0 + $1.sentences.count }
        guard totalSentences > 0 else { return 0 }
        let sentencesBefore = chapters.prefix(currentChapterIndex).reduce(0) { $0 + $1.sentences.count }
        return Double(sentencesBefore + currentSentenceIndex) / Double(totalSentences)
    }

    // MARK: - Init

    init(ttsEngine: any TTSEngineProtocol, modelContext: ModelContext? = nil) {
        self.ttsEngine = ttsEngine
        self.modelContext = modelContext
        ttsEngine.delegate = self
    }

    // MARK: - Book Loading

    func loadBook(_ book: Book) {
        stop()
        self.book = book
        self.chapters = (book.chapters ?? []).sorted { $0.spineIndex < $1.spineIndex }

        guard !chapters.isEmpty else {
            currentChapterIndex = 0
            currentSentenceIndex = 0
            return
        }

        if let position = book.readingPosition {
            currentChapterIndex = min(position.chapterIndex, chapters.count - 1)
            let sentenceCount = chapters[currentChapterIndex].sentences.count
            currentSentenceIndex = sentenceCount > 0 ? min(position.sentenceIndex, sentenceCount - 1) : 0
        } else {
            currentChapterIndex = 0
            currentSentenceIndex = 0
        }
    }

    // MARK: - Playback Controls

    func play() {
        guard !chapters.isEmpty, currentSentenceText != nil else { return }
        guard playbackState == .idle || playbackState == .paused else { return }

        if playbackState == .paused {
            ttsEngine.resume()
            playbackState = .playing
            return
        }

        playbackState = .playing
        speakCurrentSentence()
    }

    func pause() {
        guard playbackState == .playing else { return }
        ttsEngine.pause()
        playbackState = .paused
        persistPosition()
    }

    func stop() {
        playbackState = .idle
        ttsEngine.stop()
        currentWordRange = nil
        persistPosition()
    }

    func togglePlayPause() {
        switch playbackState {
        case .idle:
            play()
        case .playing:
            pause()
        case .paused:
            play()
        case .loading:
            break
        }
    }

    // MARK: - Rate

    func setRate(_ rate: Float) {
        self.rate = rate
        ttsEngine.setRate(rate)
    }

    // MARK: - Navigation

    func skipForward() {
        guard let chapter = currentChapter else { return }
        if currentSentenceIndex < chapter.sentences.count - 1 {
            currentSentenceIndex += 1
        } else if currentChapterIndex < chapters.count - 1 {
            currentChapterIndex += 1
            currentSentenceIndex = 0
        }

        if playbackState == .playing {
            ttsEngine.stop()
            speakCurrentSentence()
        }
        persistPosition()
    }

    func skipBackward() {
        if currentSentenceIndex > 0 {
            currentSentenceIndex -= 1
        } else if currentChapterIndex > 0 {
            currentChapterIndex -= 1
            let sentenceCount = currentChapter?.sentences.count ?? 1
            currentSentenceIndex = max(0, sentenceCount - 1)
        }

        if playbackState == .playing {
            ttsEngine.stop()
            speakCurrentSentence()
        }
        persistPosition()
    }

    func jumpToChapter(_ index: Int) {
        guard index >= 0, index < chapters.count else { return }
        currentChapterIndex = index
        currentSentenceIndex = 0

        if playbackState == .playing {
            ttsEngine.stop()
            speakCurrentSentence()
        }
        persistPosition()
    }

    // MARK: - TTSEngineDelegate

    func ttsEngine(_ engine: any TTSEngineProtocol, didStartUtterance utterance: Utterance) {
        // State already set when we initiated speak
    }

    func ttsEngine(_ engine: any TTSEngineProtocol, didFinishUtterance utterance: Utterance) {
        guard playbackState == .playing else { return }
        advanceToNextSentence()
    }

    func ttsEngine(_ engine: any TTSEngineProtocol, didReachWordRange range: Range<String.Index>, in utterance: Utterance) {
        currentWordRange = range
    }

    func ttsEngine(_ engine: any TTSEngineProtocol, didEncounterError error: Error) {
        playbackState = .idle
    }

    // MARK: - Private

    private func speakCurrentSentence() {
        guard let text = currentSentenceText else {
            playbackState = .idle
            return
        }
        currentWordRange = nil
        let utterance = Utterance(
            text: text,
            identifier: "\(currentChapterIndex)-\(currentSentenceIndex)"
        )
        ttsEngine.speak(utterance)
    }

    private func advanceToNextSentence() {
        guard let chapter = currentChapter else {
            playbackState = .idle
            return
        }

        if currentSentenceIndex < chapter.sentences.count - 1 {
            currentSentenceIndex += 1
            speakCurrentSentence()
        } else if currentChapterIndex < chapters.count - 1 {
            currentChapterIndex += 1
            currentSentenceIndex = 0
            persistPosition()
            speakCurrentSentence()
        } else {
            // End of book
            playbackState = .idle
            persistPosition()
        }
    }

    private func persistPosition() {
        guard let book, let modelContext else { return }
        if let position = book.readingPosition {
            position.chapterIndex = currentChapterIndex
            position.sentenceIndex = currentSentenceIndex
            position.lastUpdated = Date()
        } else {
            let position = ReadingPosition(
                chapterIndex: currentChapterIndex,
                sentenceIndex: currentSentenceIndex,
                book: book
            )
            modelContext.insert(position)
        }
        try? modelContext.save()
    }
}
