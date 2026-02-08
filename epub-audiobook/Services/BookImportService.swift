// ABOUTME: Service for importing EPUB files from the Files app into the app sandbox.
// ABOUTME: Copies the file, parses it with EPUBParser, and persists Book + Chapters to SwiftData.

import Foundation
import SwiftData

/// Errors that can occur during book import.
enum BookImportError: Error, LocalizedError {
    case fileNotAccessible
    case copyFailed(Error)
    case parsingFailed(Error)
    case duplicateBook(String)

    var errorDescription: String? {
        switch self {
        case .fileNotAccessible:
            return "The selected file could not be accessed."
        case .copyFailed(let error):
            return "Failed to copy file: \(error.localizedDescription)"
        case .parsingFailed(let error):
            return "Failed to parse EPUB: \(error.localizedDescription)"
        case .duplicateBook(let title):
            return "'\(title)' has already been imported."
        }
    }
}

/// Imports EPUB files into the app, parsing and persisting them.
@MainActor
final class BookImportService {

    private let modelContext: ModelContext

    /// Directory where imported books are stored.
    static var booksDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Books")
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Import an EPUB file, copy it to the app sandbox, parse, and persist.
    /// - Parameter sourceURL: URL from the file picker (may be security-scoped).
    /// - Returns: The persisted `Book` model.
    /// - Throws: `BookImportError` on failure.
    func importBook(from sourceURL: URL) async throws -> Book {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw BookImportError.fileNotAccessible
        }

        // Copy to app sandbox
        let booksDir = Self.booksDirectory
        try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)

        let fileName = sourceURL.lastPathComponent
        let destURL = uniqueDestination(for: fileName, in: booksDir)
        let relativePath = destURL.lastPathComponent

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            throw BookImportError.copyFailed(error)
        }

        // Parse
        let parsedBook: ParsedBook
        do {
            parsedBook = try EPUBParser.parse(epubURL: destURL)
        } catch {
            // Clean up copied file on parse failure
            try? FileManager.default.removeItem(at: destURL)
            throw BookImportError.parsingFailed(error)
        }

        let title = parsedBook.title ?? fileName

        // Check for duplicate (same title and author)
        if isDuplicate(title: title, author: parsedBook.author) {
            try? FileManager.default.removeItem(at: destURL)
            throw BookImportError.duplicateBook(title)
        }

        // Persist
        let book = Book(
            title: title,
            author: parsedBook.author,
            coverImageData: parsedBook.coverImageData,
            epubFilePath: relativePath
        )
        modelContext.insert(book)

        for (index, parsedChapter) in parsedBook.chapters.enumerated() {
            let chapter = Chapter(
                title: parsedChapter.title,
                sentences: parsedChapter.sentences,
                spineIndex: index,
                book: book
            )
            modelContext.insert(chapter)
        }

        let position = ReadingPosition(chapterIndex: 0, sentenceIndex: 0, book: book)
        modelContext.insert(position)

        try modelContext.save()

        return book
    }

    // MARK: - Private

    /// Generate a unique filename to avoid collisions.
    private func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        var dest = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            let stem = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            dest = directory.appendingPathComponent("\(stem)-\(UUID().uuidString).\(ext)")
        }
        return dest
    }

    /// Check if a book with the same title and author already exists.
    private func isDuplicate(title: String, author: String?) -> Bool {
        var descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { book in
                book.title == title
            }
        )
        descriptor.fetchLimit = 1
        guard let existing = try? modelContext.fetch(descriptor), let first = existing.first else {
            return false
        }
        return first.author == author
    }
}
