// ABOUTME: Service for creating, listing, and deleting bookmarks for a book.
// ABOUTME: Persists bookmarks to SwiftData and provides query helpers.

import Foundation
import SwiftData

@MainActor
final class BookmarkService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Create a bookmark at the given position.
    func createBookmark(
        label: String,
        chapterIndex: Int,
        sentenceIndex: Int,
        for book: Book
    ) -> Bookmark {
        let bookmark = Bookmark(
            label: label,
            chapterIndex: chapterIndex,
            sentenceIndex: sentenceIndex,
            book: book
        )
        modelContext.insert(bookmark)
        try? modelContext.save()
        return bookmark
    }

    /// Fetch all bookmarks for a book, ordered by creation date.
    func bookmarks(for book: Book) -> [Bookmark] {
        let bookID = book.persistentModelID
        var descriptor = FetchDescriptor<Bookmark>(
            sortBy: [SortDescriptor(\Bookmark.createdAt, order: .reverse)]
        )
        descriptor.predicate = #Predicate { bookmark in
            bookmark.book?.persistentModelID == bookID
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Delete a bookmark.
    func deleteBookmark(_ bookmark: Bookmark) {
        modelContext.delete(bookmark)
        try? modelContext.save()
    }
}
