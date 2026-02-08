// ABOUTME: Unit tests for TOCParser which builds chapter table of contents from NCX and nav documents.
// ABOUTME: Covers EPUB 2 NCX, EPUB 3 nav, nested chapters, and edge cases.

import XCTest
@testable import epub_audiobook

final class TOCParserTests: XCTestCase {

    // MARK: - NCX (EPUB 2)

    func test_tocParser_validNCX_returnsEntries() throws {
        // Arrange
        let xml = Data(TOCFixtures.validNCX.utf8)

        // Act
        let entries = try TOCParser.parseNCX(xml)

        // Assert
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].title, "Chapter 1")
        XCTAssertEqual(entries[0].href, "chapter1.xhtml")
        XCTAssertEqual(entries[1].title, "Chapter 2")
        XCTAssertEqual(entries[2].title, "Chapter 3")
    }

    func test_tocParser_ncxWithPlayOrder_preservesOrder() throws {
        // Arrange
        let xml = Data(TOCFixtures.validNCX.utf8)

        // Act
        let entries = try TOCParser.parseNCX(xml)

        // Assert
        XCTAssertEqual(entries[0].playOrder, 1)
        XCTAssertEqual(entries[1].playOrder, 2)
        XCTAssertEqual(entries[2].playOrder, 3)
    }

    func test_tocParser_nestedNCX_flattensWithDepth() throws {
        // Arrange
        let xml = Data(TOCFixtures.nestedNCX.utf8)

        // Act
        let entries = try TOCParser.parseNCX(xml)

        // Assert
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(entries[0].depth, 0)
        XCTAssertEqual(entries[0].title, "Part 1")
        XCTAssertEqual(entries[1].depth, 1)
        XCTAssertEqual(entries[1].title, "Chapter 1.1")
        XCTAssertEqual(entries[2].depth, 1)
        XCTAssertEqual(entries[2].title, "Chapter 1.2")
        XCTAssertEqual(entries[3].depth, 0)
        XCTAssertEqual(entries[3].title, "Part 2")
    }

    func test_tocParser_emptyNCX_returnsEmpty() throws {
        // Arrange
        let xml = Data(TOCFixtures.emptyNCX.utf8)

        // Act
        let entries = try TOCParser.parseNCX(xml)

        // Assert
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Nav (EPUB 3)

    func test_tocParser_validNav_returnsEntries() throws {
        // Arrange
        let xml = Data(TOCFixtures.validNav.utf8)

        // Act
        let entries = try TOCParser.parseNav(xml)

        // Assert
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].title, "Introduction")
        XCTAssertEqual(entries[0].href, "intro.xhtml")
        XCTAssertEqual(entries[1].title, "Chapter 1")
        XCTAssertEqual(entries[2].title, "Chapter 2")
    }

    func test_tocParser_nestedNav_flattensWithDepth() throws {
        // Arrange
        let xml = Data(TOCFixtures.nestedNav.utf8)

        // Act
        let entries = try TOCParser.parseNav(xml)

        // Assert
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(entries[0].depth, 0)
        XCTAssertEqual(entries[1].depth, 1)
        XCTAssertEqual(entries[2].depth, 1)
        XCTAssertEqual(entries[3].depth, 0)
    }

    func test_tocParser_emptyNav_returnsEmpty() throws {
        // Arrange
        let xml = Data(TOCFixtures.emptyNav.utf8)

        // Act
        let entries = try TOCParser.parseNav(xml)

        // Assert
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Error Handling

    func test_tocParser_malformedNCX_throwsError() {
        // Arrange
        let xml = Data("<ncx><navMap><navPoint".utf8)

        // Act & Assert
        XCTAssertThrowsError(try TOCParser.parseNCX(xml))
    }

    func test_tocParser_emptyData_throwsError() {
        // Act & Assert
        XCTAssertThrowsError(try TOCParser.parseNCX(Data()))
        XCTAssertThrowsError(try TOCParser.parseNav(Data()))
    }
}

// MARK: - Fixtures

private enum TOCFixtures {

    static let validNCX = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
      <navMap>
        <navPoint id="ch1" playOrder="1">
          <navLabel><text>Chapter 1</text></navLabel>
          <content src="chapter1.xhtml"/>
        </navPoint>
        <navPoint id="ch2" playOrder="2">
          <navLabel><text>Chapter 2</text></navLabel>
          <content src="chapter2.xhtml"/>
        </navPoint>
        <navPoint id="ch3" playOrder="3">
          <navLabel><text>Chapter 3</text></navLabel>
          <content src="chapter3.xhtml"/>
        </navPoint>
      </navMap>
    </ncx>
    """

    static let nestedNCX = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
      <navMap>
        <navPoint id="p1" playOrder="1">
          <navLabel><text>Part 1</text></navLabel>
          <content src="part1.xhtml"/>
          <navPoint id="ch11" playOrder="2">
            <navLabel><text>Chapter 1.1</text></navLabel>
            <content src="ch1-1.xhtml"/>
          </navPoint>
          <navPoint id="ch12" playOrder="3">
            <navLabel><text>Chapter 1.2</text></navLabel>
            <content src="ch1-2.xhtml"/>
          </navPoint>
        </navPoint>
        <navPoint id="p2" playOrder="4">
          <navLabel><text>Part 2</text></navLabel>
          <content src="part2.xhtml"/>
        </navPoint>
      </navMap>
    </ncx>
    """

    static let emptyNCX = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
      <navMap>
      </navMap>
    </ncx>
    """

    static let validNav = """
    <?xml version="1.0" encoding="UTF-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
    <body>
      <nav epub:type="toc">
        <ol>
          <li><a href="intro.xhtml">Introduction</a></li>
          <li><a href="ch1.xhtml">Chapter 1</a></li>
          <li><a href="ch2.xhtml">Chapter 2</a></li>
        </ol>
      </nav>
    </body>
    </html>
    """

    static let nestedNav = """
    <?xml version="1.0" encoding="UTF-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
    <body>
      <nav epub:type="toc">
        <ol>
          <li>
            <a href="part1.xhtml">Part 1</a>
            <ol>
              <li><a href="ch1-1.xhtml">Chapter 1.1</a></li>
              <li><a href="ch1-2.xhtml">Chapter 1.2</a></li>
            </ol>
          </li>
          <li><a href="part2.xhtml">Part 2</a></li>
        </ol>
      </nav>
    </body>
    </html>
    """

    static let emptyNav = """
    <?xml version="1.0" encoding="UTF-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
    <body>
      <nav epub:type="toc">
        <ol>
        </ol>
      </nav>
    </body>
    </html>
    """
}
