// ABOUTME: SwiftData model for a single chapter within an EPUB book.
// ABOUTME: Stores extracted text as an array of sentences and the spine index for ordering.

import Foundation
import SwiftData

@Model
final class Chapter {
    var title: String
    var sentences: [String]
    var spineIndex: Int
    var book: Book?

    init(
        title: String,
        sentences: [String],
        spineIndex: Int,
        book: Book? = nil
    ) {
        self.title = title
        self.sentences = sentences
        self.spineIndex = spineIndex
        self.book = book
    }
}
