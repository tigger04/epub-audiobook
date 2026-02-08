// ABOUTME: Tests for BookmarkService CRUD operations.
// ABOUTME: Verifies create, list, and delete with in-memory SwiftData container.

import XCTest
import SwiftData
@testable import epub_audiobook

@MainActor
final class BookmarkServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: BookmarkService!
    private var book: Book!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Book.self, Chapter.self, ReadingPosition.self, Bookmark.self,
            configurations: config
        )
        context = container.mainContext
        service = BookmarkService(modelContext: context)

        book = Book(title: "Test Book", epubFilePath: "/test.epub")
        context.insert(book)
        try context.save()
    }

    override func tearDown() async throws {
        book = nil
        service = nil
        container = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - Create

    func test_createBookmark_persistsToContext() throws {
        let bookmark = service.createBookmark(
            label: "Important passage",
            chapterIndex: 2,
            sentenceIndex: 5,
            for: book
        )

        XCTAssertEqual(bookmark.label, "Important passage")
        XCTAssertEqual(bookmark.chapterIndex, 2)
        XCTAssertEqual(bookmark.sentenceIndex, 5)
        XCTAssertEqual(bookmark.book?.title, "Test Book")
    }

    func test_createBookmark_multipleBookmarks_allPersisted() throws {
        _ = service.createBookmark(label: "BM1", chapterIndex: 0, sentenceIndex: 0, for: book)
        _ = service.createBookmark(label: "BM2", chapterIndex: 1, sentenceIndex: 3, for: book)
        _ = service.createBookmark(label: "BM3", chapterIndex: 2, sentenceIndex: 1, for: book)

        let descriptor = FetchDescriptor<Bookmark>()
        let bookmarks = try context.fetch(descriptor)
        XCTAssertEqual(bookmarks.count, 3)
    }

    // MARK: - List

    func test_bookmarks_returnsBookmarksForSpecificBook() throws {
        _ = service.createBookmark(label: "BM1", chapterIndex: 0, sentenceIndex: 0, for: book)

        let otherBook = Book(title: "Other Book", epubFilePath: "/other.epub")
        context.insert(otherBook)
        try context.save()
        _ = service.createBookmark(label: "Other BM", chapterIndex: 0, sentenceIndex: 0, for: otherBook)

        let bookmarks = service.bookmarks(for: book)
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks.first?.label, "BM1")
    }

    func test_bookmarks_orderedByCreationDateDescending() throws {
        let bm1 = service.createBookmark(label: "First", chapterIndex: 0, sentenceIndex: 0, for: book)
        // Ensure different timestamps
        bm1.createdAt = Date(timeIntervalSinceNow: -100)
        try context.save()

        _ = service.createBookmark(label: "Second", chapterIndex: 1, sentenceIndex: 0, for: book)

        let bookmarks = service.bookmarks(for: book)
        XCTAssertEqual(bookmarks.count, 2)
        XCTAssertEqual(bookmarks.first?.label, "Second")
    }

    // MARK: - Delete

    func test_deleteBookmark_removesFromContext() throws {
        let bookmark = service.createBookmark(label: "To Delete", chapterIndex: 0, sentenceIndex: 0, for: book)

        service.deleteBookmark(bookmark)

        let descriptor = FetchDescriptor<Bookmark>()
        let bookmarks = try context.fetch(descriptor)
        XCTAssertTrue(bookmarks.isEmpty)
    }

    func test_deleteBookmark_doesNotAffectOtherBookmarks() throws {
        _ = service.createBookmark(label: "Keep", chapterIndex: 0, sentenceIndex: 0, for: book)
        let toDelete = service.createBookmark(label: "Delete", chapterIndex: 1, sentenceIndex: 0, for: book)

        service.deleteBookmark(toDelete)

        let bookmarks = service.bookmarks(for: book)
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks.first?.label, "Keep")
    }
}
