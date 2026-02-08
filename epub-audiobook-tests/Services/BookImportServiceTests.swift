// ABOUTME: Tests for BookImportService covering import, persistence, and duplicate detection.
// ABOUTME: Uses in-memory SwiftData container and programmatic EPUB fixtures.

import XCTest
import SwiftData
import ZIPFoundation
@testable import epub_audiobook

@MainActor
final class BookImportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: BookImportService!
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Book.self, Chapter.self, ReadingPosition.self, Bookmark.self,
            configurations: config
        )
        context = container.mainContext
        service = BookImportService(modelContext: context)
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        container = nil
        context = nil
        service = nil
        tempDir = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Create a minimal EPUB file for testing.
    private func createTestEPUB(
        title: String = "Test Book",
        author: String = "Test Author",
        fileName: String = "test.epub"
    ) throws -> URL {
        let epubURL = tempDir.appendingPathComponent(fileName)
        let archive = try Archive(url: epubURL, accessMode: .create)

        // mimetype (must be first, uncompressed)
        let mimeData = Data("application/epub+zip".utf8)
        try archive.addEntry(
            with: "mimetype",
            type: .file,
            uncompressedSize: Int64(mimeData.count),
            compressionMethod: .none,
            provider: { position, size in
                mimeData[Int(position)..<Int(position) + size]
            }
        )

        // container.xml
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"
                   version="1.0">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf"
                      media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        try addEntry(to: archive, path: "META-INF/container.xml", content: containerXML)

        // content.opf
        let opfXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>\(title)</dc:title>
            <dc:creator>\(author)</dc:creator>
            <dc:identifier id="uid">test-isbn-123</dc:identifier>
          </metadata>
          <manifest>
            <item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="ch1"/>
          </spine>
        </package>
        """
        try addEntry(to: archive, path: "OEBPS/content.opf", content: opfXML)

        // chapter1.xhtml
        let chapterXHTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>Chapter 1</title></head>
        <body>
          <h1>Chapter One</h1>
          <p>This is the first sentence. This is the second sentence.</p>
        </body>
        </html>
        """
        try addEntry(to: archive, path: "OEBPS/chapter1.xhtml", content: chapterXHTML)

        return epubURL
    }

    private func addEntry(to archive: Archive, path: String, content: String) throws {
        let data = Data(content.utf8)
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            provider: { position, size in
                data[Int(position)..<Int(position) + size]
            }
        )
    }

    // MARK: - Import Tests

    func test_importBook_persistsBookToContext() async throws {
        // Arrange
        let epubURL = try createTestEPUB()

        // Act
        let book = try await service.importBook(from: epubURL)

        // Assert
        XCTAssertEqual(book.title, "Test Book")
        XCTAssertEqual(book.author, "Test Author")

        let descriptor = FetchDescriptor<Book>()
        let books = try context.fetch(descriptor)
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?.title, "Test Book")
    }

    func test_importBook_persistsChapters() async throws {
        // Arrange
        let epubURL = try createTestEPUB()

        // Act
        let book = try await service.importBook(from: epubURL)

        // Assert
        let descriptor = FetchDescriptor<Chapter>()
        let chapters = try context.fetch(descriptor)
        XCTAssertFalse(chapters.isEmpty)
        XCTAssertEqual(chapters.first?.book?.title, book.title)
    }

    func test_importBook_createsReadingPosition() async throws {
        // Arrange
        let epubURL = try createTestEPUB()

        // Act
        let book = try await service.importBook(from: epubURL)

        // Assert
        XCTAssertNotNil(book.readingPosition)
        XCTAssertEqual(book.readingPosition?.chapterIndex, 0)
        XCTAssertEqual(book.readingPosition?.sentenceIndex, 0)
    }

    func test_importBook_copiesFileToDocuments() async throws {
        // Arrange
        let epubURL = try createTestEPUB()

        // Act
        let book = try await service.importBook(from: epubURL)

        // Assert — epubFilePath should be relative, not absolute
        XCTAssertFalse(book.epubFilePath.hasPrefix("/"))
        let docsDir = BookImportService.booksDirectory
        let fullPath = docsDir.appendingPathComponent(book.epubFilePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fullPath.path))
    }

    func test_importBook_duplicateImport_throwsError() async throws {
        // Arrange
        let epubURL = try createTestEPUB()
        _ = try await service.importBook(from: epubURL)

        // Act / Assert
        do {
            _ = try await service.importBook(from: epubURL)
            XCTFail("Expected duplicate import error")
        } catch let error as BookImportError {
            if case .duplicateBook = error {
                // Expected
            } else {
                XCTFail("Expected duplicateBook error, got \(error)")
            }
        }
    }

    func test_importBook_invalidFile_throwsError() async throws {
        // Arrange
        let invalidURL = tempDir.appendingPathComponent("nonexistent.epub")

        // Act / Assert
        do {
            _ = try await service.importBook(from: invalidURL)
            XCTFail("Expected error for invalid file")
        } catch {
            // Expected — file not found or parsing error
        }
    }

    func test_importBook_multipleBooks_allPersisted() async throws {
        // Arrange
        let epub1 = try createTestEPUB(title: "Book One", author: "Author A", fileName: "book1.epub")
        let epub2 = try createTestEPUB(title: "Book Two", author: "Author B", fileName: "book2.epub")

        // Act
        _ = try await service.importBook(from: epub1)
        _ = try await service.importBook(from: epub2)

        // Assert
        let descriptor = FetchDescriptor<Book>()
        let books = try context.fetch(descriptor)
        XCTAssertEqual(books.count, 2)
        let titles = Set(books.map(\.title))
        XCTAssertTrue(titles.contains("Book One"))
        XCTAssertTrue(titles.contains("Book Two"))
    }
}
