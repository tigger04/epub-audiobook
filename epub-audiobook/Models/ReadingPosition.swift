// ABOUTME: SwiftData model for tracking the user's reading position within a book.
// ABOUTME: Stores chapter and sentence indices for resume-on-launch functionality.

import Foundation
import SwiftData

@Model
final class ReadingPosition {
    var chapterIndex: Int
    var sentenceIndex: Int
    var lastUpdated: Date
    var book: Book?

    init(
        chapterIndex: Int = 0,
        sentenceIndex: Int = 0,
        lastUpdated: Date = Date(),
        book: Book? = nil
    ) {
        self.chapterIndex = chapterIndex
        self.sentenceIndex = sentenceIndex
        self.lastUpdated = lastUpdated
        self.book = book
    }
}
