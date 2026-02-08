// ABOUTME: SwiftData model for an imported EPUB book.
// ABOUTME: Stores metadata, file path, and relationships to chapters, position, and bookmarks.

import Foundation
import SwiftData

@Model
final class Book {
    var title: String
    var author: String?
    @Attribute(.externalStorage) var coverImageData: Data?
    var epubFilePath: String
    var importDate: Date

    @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
    var chapters: [Chapter]?

    @Relationship(deleteRule: .cascade, inverse: \ReadingPosition.book)
    var readingPosition: ReadingPosition?

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.book)
    var bookmarks: [Bookmark]?

    init(
        title: String,
        author: String? = nil,
        coverImageData: Data? = nil,
        epubFilePath: String,
        importDate: Date = Date()
    ) {
        self.title = title
        self.author = author
        self.coverImageData = coverImageData
        self.epubFilePath = epubFilePath
        self.importDate = importDate
    }
}
