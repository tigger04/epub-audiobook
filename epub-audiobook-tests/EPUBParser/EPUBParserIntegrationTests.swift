// ABOUTME: Integration tests for EPUBParser coordinator.
// ABOUTME: Creates minimal EPUB fixtures programmatically and verifies full parsing pipeline.

import XCTest
import ZIPFoundation
@testable import epub_audiobook

final class EPUBParserIntegrationTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epub-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Full Pipeline

    func test_epubParser_validEPUB_parsesCompletely() throws {
        // Arrange
        let epubURL = try createMinimalEPUB(
            title: "Test Book",
            author: "Test Author",
            chapters: [
                ("Chapter 1", "<p>First sentence of chapter one. Second sentence of chapter one.</p>"),
                ("Chapter 2", "<p>First sentence of chapter two.</p>"),
            ]
        )

        // Act
        let book = try EPUBParser.parse(epubURL: epubURL)

        // Assert
        XCTAssertEqual(book.title, "Test Book")
        XCTAssertEqual(book.author, "Test Author")
        XCTAssertEqual(book.chapters.count, 2)
        XCTAssertEqual(book.chapters[0].title, "Chapter 1")
        // h1 heading + 2 paragraph sentences = 3 sentences
        XCTAssertEqual(book.chapters[0].sentences.count, 3)
        XCTAssertEqual(book.chapters[0].sentences[0], "Chapter 1")
        XCTAssertEqual(book.chapters[0].sentences[1], "First sentence of chapter one.")
        XCTAssertEqual(book.chapters[0].sentences[2], "Second sentence of chapter one.")
        XCTAssertEqual(book.chapters[1].title, "Chapter 2")
        // h1 heading + 1 paragraph sentence = 2 sentences
        XCTAssertEqual(book.chapters[1].sentences.count, 2)
    }

    func test_epubParser_missingTOC_usesSpineOrder() throws {
        // Arrange — EPUB without NCX or nav document
        let epubURL = try createMinimalEPUB(
            title: "No TOC Book",
            author: "Author",
            chapters: [
                ("ch1", "<p>Hello from chapter one.</p>"),
            ],
            includeTOC: false
        )

        // Act
        let book = try EPUBParser.parse(epubURL: epubURL)

        // Assert
        XCTAssertEqual(book.chapters.count, 1)
        // Without TOC, title falls back to first sentence
        XCTAssertFalse(book.chapters[0].sentences.isEmpty)
    }

    func test_epubParser_fileNotFound_throwsError() {
        // Arrange
        let fakeURL = tempDir.appendingPathComponent("nonexistent.epub")

        // Act & Assert
        XCTAssertThrowsError(try EPUBParser.parse(epubURL: fakeURL)) { error in
            guard let epubError = error as? EPUBParserError else {
                XCTFail("Expected EPUBParserError, got \(error)")
                return
            }
            if case .fileNotFound = epubError {
                // Expected
            } else {
                XCTFail("Expected .fileNotFound, got \(epubError)")
            }
        }
    }

    func test_epubParser_extractedDirectory_parsesCorrectly() throws {
        // Arrange — create an extracted EPUB directory structure directly
        let extractedDir = try createExtractedEPUBDirectory(
            title: "Extracted Book",
            author: "Direct Author",
            chapters: [
                ("Chapter A", "<p>Text from chapter A.</p>"),
            ]
        )

        // Act
        let book = try EPUBParser.parseExtractedEPUB(at: extractedDir)

        // Assert
        XCTAssertEqual(book.title, "Extracted Book")
        XCTAssertEqual(book.author, "Direct Author")
        XCTAssertEqual(book.chapters.count, 1)
    }

    // MARK: - EPUB Fixture Creation

    private func createMinimalEPUB(
        title: String,
        author: String,
        chapters: [(String, String)],
        includeTOC: Bool = true
    ) throws -> URL {
        let epubDir = try createExtractedEPUBDirectory(
            title: title,
            author: author,
            chapters: chapters,
            includeTOC: includeTOC
        )

        // Create EPUB archive with files at root level (not wrapped in directory)
        let epubURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).epub")
        let archive = try Archive(url: epubURL, accessMode: .create)

        let enumerator = FileManager.default.enumerator(at: epubDir, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir)
            guard !isDir.boolValue else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: epubDir.path + "/", with: "")
            let fileData = try Data(contentsOf: fileURL)
            try archive.addEntry(
                with: relativePath,
                type: .file,
                uncompressedSize: Int64(fileData.count),
                provider: { position, size in
                    fileData[Int(position)..<Int(position) + size]
                }
            )
        }

        return epubURL
    }

    private func createExtractedEPUBDirectory(
        title: String,
        author: String,
        chapters: [(String, String)],
        includeTOC: Bool = true
    ) throws -> URL {
        let epubDir = tempDir.appendingPathComponent("epub-content-\(UUID().uuidString)")
        let metaInfDir = epubDir.appendingPathComponent("META-INF")
        let oebpsDir = epubDir.appendingPathComponent("OEBPS")

        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true)

        // container.xml
        let containerXML = """
        <?xml version="1.0"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        try containerXML.write(to: metaInfDir.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        // Build manifest and spine entries
        var manifestItems = ""
        var spineItems = ""
        var ncxNavPoints = ""

        for (index, chapter) in chapters.enumerated() {
            let id = "chapter\(index + 1)"
            let filename = "\(id).xhtml"
            manifestItems += "    <item id=\"\(id)\" href=\"\(filename)\" media-type=\"application/xhtml+xml\"/>\n"
            spineItems += "    <itemref idref=\"\(id)\"/>\n"

            // Chapter XHTML
            let xhtml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <head><title>\(chapter.0)</title></head>
            <body>
              <h1>\(chapter.0)</h1>
              \(chapter.1)
            </body>
            </html>
            """
            try xhtml.write(to: oebpsDir.appendingPathComponent(filename), atomically: true, encoding: .utf8)

            // NCX entry
            ncxNavPoints += """
                <navPoint id="\(id)" playOrder="\(index + 1)">
                  <navLabel><text>\(chapter.0)</text></navLabel>
                  <content src="\(filename)"/>
                </navPoint>\n
            """
        }

        if includeTOC {
            manifestItems += "    <item id=\"ncx\" href=\"toc.ncx\" media-type=\"application/x-dtbncx+xml\"/>\n"
        }

        // content.opf
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="uid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>\(title)</dc:title>
            <dc:creator>\(author)</dc:creator>
          </metadata>
          <manifest>
        \(manifestItems)  </manifest>
          <spine\(includeTOC ? " toc=\"ncx\"" : "")>
        \(spineItems)  </spine>
        </package>
        """
        try opf.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        // toc.ncx
        if includeTOC {
            let ncx = """
            <?xml version="1.0" encoding="UTF-8"?>
            <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
              <navMap>
            \(ncxNavPoints)  </navMap>
            </ncx>
            """
            try ncx.write(to: oebpsDir.appendingPathComponent("toc.ncx"), atomically: true, encoding: .utf8)
        }

        return epubDir
    }
}
