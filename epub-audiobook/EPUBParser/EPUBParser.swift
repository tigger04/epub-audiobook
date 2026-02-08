// ABOUTME: Top-level EPUB parser that orchestrates ZIP extraction through all parsing stages.
// ABOUTME: Takes an EPUB file URL and returns a fully parsed book with chapters and metadata.

import Foundation
import ZIPFoundation

/// A parsed chapter from an EPUB file.
struct ParsedChapter: Equatable, Sendable {
    let title: String
    let sentences: [String]
    let href: String
}

/// The complete result of parsing an EPUB file.
struct ParsedBook: Equatable, Sendable {
    let title: String?
    let author: String?
    let coverImageData: Data?
    let chapters: [ParsedChapter]
}

/// Errors that can occur during EPUB parsing.
enum EPUBParserError: Error {
    case fileNotFound
    case zipExtractionFailed(String)
    case containerNotFound
    case containerParsingFailed(Error)
    case opfNotFound
    case opfParsingFailed(Error)
    case noChaptersFound
}

/// Orchestrates EPUB parsing: ZIP extraction → container → OPF → TOC → text extraction.
enum EPUBParser {

    /// Parse an EPUB file and return a structured book.
    /// - Parameter epubURL: File URL to the .epub file.
    /// - Returns: A `ParsedBook` with metadata and chapters.
    /// - Throws: `EPUBParserError` for each failure mode.
    static func parse(epubURL: URL) throws -> ParsedBook {
        guard FileManager.default.fileExists(atPath: epubURL.path) else {
            throw EPUBParserError.fileNotFound
        }

        // Extract ZIP to temporary directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epub-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: epubURL, to: tempDir)
        } catch {
            throw EPUBParserError.zipExtractionFailed(error.localizedDescription)
        }

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        return try parseExtractedEPUB(at: tempDir)
    }

    /// Parse an already-extracted EPUB directory.
    static func parseExtractedEPUB(at directory: URL) throws -> ParsedBook {
        // 1. Parse container.xml
        let containerURL = directory
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")

        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw EPUBParserError.containerNotFound
        }

        let containerData = try Data(contentsOf: containerURL)
        let containerResult: ContainerResult
        do {
            containerResult = try ContainerParser.parse(containerData)
        } catch {
            throw EPUBParserError.containerParsingFailed(error)
        }

        // 2. Parse OPF
        let opfURL = directory.appendingPathComponent(containerResult.opfPath)
        let opfBaseURL = opfURL.deletingLastPathComponent()

        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw EPUBParserError.opfNotFound
        }

        let opfData = try Data(contentsOf: opfURL)
        let opfResult: OPFResult
        do {
            opfResult = try OPFParser.parse(opfData)
        } catch {
            throw EPUBParserError.opfParsingFailed(error)
        }

        // 3. Try to parse TOC (optional — some EPUBs lack a TOC)
        let tocEntries = parseTOC(opfResult: opfResult, baseURL: opfBaseURL)

        // 4. Build chapters from spine
        let chapters = buildChapters(
            opfResult: opfResult,
            tocEntries: tocEntries,
            baseURL: opfBaseURL
        )

        // 5. Load cover image data
        let coverData = loadCoverImage(opfResult: opfResult, baseURL: opfBaseURL)

        return ParsedBook(
            title: opfResult.metadata.title,
            author: opfResult.metadata.author,
            coverImageData: coverData,
            chapters: chapters
        )
    }

    // MARK: - TOC Parsing

    private static func parseTOC(opfResult: OPFResult, baseURL: URL) -> [TOCEntry] {
        // Try EPUB 3 nav first
        if let navItem = opfResult.manifest.first(where: { $0.properties?.contains("nav") == true }) {
            let navURL = baseURL.appendingPathComponent(navItem.href)
            if let navData = try? Data(contentsOf: navURL),
               let entries = try? TOCParser.parseNav(navData),
               !entries.isEmpty {
                return entries
            }
        }

        // Fall back to EPUB 2 NCX
        if let ncxItem = opfResult.manifest.first(where: { $0.mediaType == "application/x-dtbncx+xml" }) {
            let ncxURL = baseURL.appendingPathComponent(ncxItem.href)
            if let ncxData = try? Data(contentsOf: ncxURL),
               let entries = try? TOCParser.parseNCX(ncxData),
               !entries.isEmpty {
                return entries
            }
        }

        return []
    }

    // MARK: - Chapter Building

    private static func buildChapters(
        opfResult: OPFResult,
        tocEntries: [TOCEntry],
        baseURL: URL
    ) -> [ParsedChapter] {
        // Map manifest items by ID for quick lookup
        let manifestByID = Dictionary(uniqueKeysWithValues: opfResult.manifest.map { ($0.id, $0) })

        // Build TOC lookup by href (strip fragment identifiers)
        let tocByHref = Dictionary(tocEntries.map { entry in
            let href = entry.href.components(separatedBy: "#").first ?? entry.href
            return (href, entry)
        }, uniquingKeysWith: { first, _ in first })

        var chapters: [ParsedChapter] = []

        for idref in opfResult.spineItemRefs {
            guard let item = manifestByID[idref] else { continue }

            // Only process XHTML content
            guard item.mediaType == "application/xhtml+xml" else { continue }

            let chapterURL = baseURL.appendingPathComponent(item.href)
            guard let chapterData = try? Data(contentsOf: chapterURL) else { continue }

            let sentences = XHTMLTextExtractor.extract(chapterData)
            guard !sentences.isEmpty else { continue }

            // Get title from TOC, or fall back to first sentence
            let title: String
            if let tocEntry = tocByHref[item.href] {
                title = tocEntry.title
            } else {
                title = sentences.first ?? item.href
            }

            chapters.append(ParsedChapter(
                title: title,
                sentences: sentences,
                href: item.href
            ))
        }

        return chapters
    }

    // MARK: - Cover Image

    private static func loadCoverImage(opfResult: OPFResult, baseURL: URL) -> Data? {
        guard let coverHref = opfResult.coverImageHref else { return nil }
        let coverURL = baseURL.appendingPathComponent(coverHref)
        return try? Data(contentsOf: coverURL)
    }
}
