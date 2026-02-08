// ABOUTME: Unit tests for XHTMLTextExtractor which strips HTML and splits text into sentences.
// ABOUTME: Covers clean XHTML, entities, malformed HTML, empty content, and paragraph boundaries.

import XCTest
@testable import epub_audiobook

final class XHTMLTextExtractorTests: XCTestCase {

    // MARK: - Clean XHTML

    func test_extractor_cleanXHTML_extractsSentences() throws {
        // Arrange
        let xhtml = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
          <p>This is the first sentence. This is the second sentence.</p>
          <p>This is the third sentence.</p>
        </body>
        </html>
        """.utf8)

        // Act
        let sentences = XHTMLTextExtractor.extract(xhtml)

        // Assert
        XCTAssertEqual(sentences.count, 3)
        XCTAssertEqual(sentences[0], "This is the first sentence.")
        XCTAssertEqual(sentences[1], "This is the second sentence.")
        XCTAssertEqual(sentences[2], "This is the third sentence.")
    }

    func test_extractor_multipleElements_stripsAllTags() throws {
        // Arrange
        let xhtml = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
          <h1>Chapter Title</h1>
          <p>First paragraph with <em>emphasis</em> and <strong>bold</strong> text.</p>
          <p>Second paragraph with a <a href="link.html">link</a>.</p>
        </body>
        </html>
        """.utf8)

        // Act
        let sentences = XHTMLTextExtractor.extract(xhtml)

        // Assert
        XCTAssertTrue(sentences.contains("Chapter Title"))
        XCTAssertTrue(sentences.contains("First paragraph with emphasis and bold text."))
        XCTAssertTrue(sentences.contains("Second paragraph with a link."))
    }

    // MARK: - Entities

    func test_extractor_htmlEntities_decodesCorrectly() throws {
        // Arrange
        let xhtml = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
          <p>Tom &amp; Jerry went to the park.</p>
          <p>The value is &lt;100&gt; units.</p>
        </body>
        </html>
        """.utf8)

        // Act
        let sentences = XHTMLTextExtractor.extract(xhtml)

        // Assert
        XCTAssertTrue(sentences.contains("Tom & Jerry went to the park."))
        XCTAssertTrue(sentences.contains("The value is <100> units."))
    }

    // MARK: - Empty Content

    func test_extractor_emptyBody_returnsEmpty() {
        // Arrange
        let xhtml = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body></body>
        </html>
        """.utf8)

        // Act
        let sentences = XHTMLTextExtractor.extract(xhtml)

        // Assert
        XCTAssertTrue(sentences.isEmpty)
    }

    func test_extractor_emptyData_returnsEmpty() {
        // Arrange & Act
        let sentences = XHTMLTextExtractor.extract(Data())

        // Assert
        XCTAssertTrue(sentences.isEmpty)
    }

    // MARK: - Whitespace

    func test_extractor_excessiveWhitespace_collapsesAndTrims() throws {
        // Arrange
        let xhtml = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
          <p>   Lots   of    spaces   here.   </p>
        </body>
        </html>
        """.utf8)

        // Act
        let sentences = XHTMLTextExtractor.extract(xhtml)

        // Assert
        XCTAssertEqual(sentences.count, 1)
        XCTAssertEqual(sentences[0], "Lots of spaces here.")
    }

    // MARK: - Malformed HTML

    func test_extractor_malformedHTML_usesRegexFallback() {
        // Arrange — not valid XML, but common in EPUBs
        let html = Data("""
        <html>
        <body>
        <p>This paragraph is not closed.
        <p>Neither is this one.
        <br>A line break without closing.
        </body>
        </html>
        """.utf8)

        // Act
        let sentences = XHTMLTextExtractor.extract(html)

        // Assert — should extract some text even from malformed HTML
        XCTAssertFalse(sentences.isEmpty)
    }

    // MARK: - Script/Style Exclusion

    func test_extractor_scriptAndStyle_excluded() throws {
        // Arrange
        let xhtml = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <style>body { color: red; }</style>
          <script>var x = 1;</script>
        </head>
        <body>
          <p>Visible text only.</p>
        </body>
        </html>
        """.utf8)

        // Act
        let sentences = XHTMLTextExtractor.extract(xhtml)

        // Assert
        XCTAssertEqual(sentences.count, 1)
        XCTAssertEqual(sentences[0], "Visible text only.")
    }

    // MARK: - Paragraph Boundaries

    func test_extractor_paragraphBoundaries_separateSentences() throws {
        // Arrange
        let xhtml = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
          <p>End of paragraph one</p>
          <p>Start of paragraph two</p>
        </body>
        </html>
        """.utf8)

        // Act
        let sentences = XHTMLTextExtractor.extract(xhtml)

        // Assert — paragraphs without periods should still be separate entries
        XCTAssertEqual(sentences.count, 2)
        XCTAssertEqual(sentences[0], "End of paragraph one")
        XCTAssertEqual(sentences[1], "Start of paragraph two")
    }
}
