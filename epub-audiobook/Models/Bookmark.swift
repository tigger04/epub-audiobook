// ABOUTME: SwiftData model for a user-created bookmark within a book.
// ABOUTME: Stores the position (chapter + sentence) and a user-defined label.

import Foundation
import SwiftData

@Model
final class Bookmark {
    var label: String
    var chapterIndex: Int
    var sentenceIndex: Int
    var createdAt: Date
    var book: Book?

    init(
        label: String,
        chapterIndex: Int,
        sentenceIndex: Int,
        createdAt: Date = Date(),
        book: Book? = nil
    ) {
        self.label = label
        self.chapterIndex = chapterIndex
        self.sentenceIndex = sentenceIndex
        self.createdAt = createdAt
        self.book = book
    }
}
