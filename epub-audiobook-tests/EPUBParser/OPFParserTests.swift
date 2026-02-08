// ABOUTME: Unit tests for OPFParser which extracts metadata, manifest, and spine from OPF documents.
// ABOUTME: Covers EPUB 2, EPUB 3, missing fields, and edge cases.

import XCTest
@testable import epub_audiobook

final class OPFParserTests: XCTestCase {

    // MARK: - EPUB 2 Format

    func test_opfParser_epub2ValidOPF_extractsMetadata() throws {
        // Arrange
        let xml = Data(TestFixtures.epub2OPF.utf8)

        // Act
        let result = try OPFParser.parse(xml)

        // Assert
        XCTAssertEqual(result.metadata.title, "A Sample Book")
        XCTAssertEqual(result.metadata.author, "Jane Author")
    }

    func test_opfParser_epub2ValidOPF_extractsManifest() throws {
        // Arrange
        let xml = Data(TestFixtures.epub2OPF.utf8)

        // Act
        let result = try OPFParser.parse(xml)

        // Assert
        XCTAssertEqual(result.manifest.count, 4)
        let chapter1 = result.manifest.first { $0.id == "chapter1" }
        XCTAssertNotNil(chapter1)
        XCTAssertEqual(chapter1?.href, "chapter1.xhtml")
        XCTAssertEqual(chapter1?.mediaType, "application/xhtml+xml")
    }

    func test_opfParser_epub2ValidOPF_extractsSpine() throws {
        // Arrange
        let xml = Data(TestFixtures.epub2OPF.utf8)

        // Act
        let result = try OPFParser.parse(xml)

        // Assert
        XCTAssertEqual(result.spineItemRefs, ["chapter1", "chapter2"])
    }

    func test_opfParser_epub2CoverMeta_extractsCoverID() throws {
        // Arrange
        let xml = Data(TestFixtures.epub2OPF.utf8)

        // Act
        let result = try OPFParser.parse(xml)

        // Assert
        XCTAssertEqual(result.metadata.coverImageID, "cover-img")
    }

    // MARK: - EPUB 3 Format

    func test_opfParser_epub3ValidOPF_extractsMetadata() throws {
        // Arrange
        let xml = Data(TestFixtures.epub3OPF.utf8)

        // Act
        let result = try OPFParser.parse(xml)

        // Assert
        XCTAssertEqual(result.metadata.title, "Modern Book")
        XCTAssertEqual(result.metadata.author, "John Writer")
    }

    func test_opfParser_epub3CoverProperty_extractsCoverID() throws {
        // Arrange
        let xml = Data(TestFixtures.epub3OPF.utf8)

        // Act
        let result = try OPFParser.parse(xml)

        // Assert
        XCTAssertEqual(result.metadata.coverImageID, "cover-image")
    }

    // MARK: - Missing Fields

    func test_opfParser_missingTitle_returnsNilTitle() throws {
        // Arrange
        let xml = Data(TestFixtures.opfMissingTitle.utf8)

        // Act
        let result = try OPFParser.parse(xml)

        // Assert
        XCTAssertNil(result.metadata.title)
    }

    func test_opfParser_missingAuthor_returnsNilAuthor() throws {
        // Arrange
        let xml = Data(TestFixtures.opfMissingTitle.utf8)

        // Act
        let result = try OPFParser.parse(xml)

        // Assert
        XCTAssertNil(result.metadata.author)
    }

    // MARK: - Edge Cases

    func test_opfParser_emptyData_throwsError() {
        // Arrange
        let xml = Data()

        // Act & Assert
        XCTAssertThrowsError(try OPFParser.parse(xml))
    }

    func test_opfParser_malformedXML_throwsError() {
        // Arrange
        let xml = Data("<package><metadata><dc:title>broken".utf8)

        // Act & Assert
        XCTAssertThrowsError(try OPFParser.parse(xml))
    }

    func test_opfParser_emptySpine_returnsEmptyList() throws {
        // Arrange
        let xml = Data(TestFixtures.opfEmptySpine.utf8)

        // Act
        let result = try OPFParser.parse(xml)

        // Assert
        XCTAssertTrue(result.spineItemRefs.isEmpty)
    }

    func test_opfParser_coverImageHref_resolvesFromManifest() throws {
        // Arrange
        let xml = Data(TestFixtures.epub2OPF.utf8)

        // Act
        let result = try OPFParser.parse(xml)

        // Assert
        let coverHref = result.coverImageHref
        XCTAssertEqual(coverHref, "images/cover.jpg")
    }
}

// MARK: - Test Fixtures

private enum TestFixtures {

    static let epub2OPF = """
    <?xml version="1.0" encoding="UTF-8"?>
    <package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="uid">
      <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
        <dc:title>A Sample Book</dc:title>
        <dc:creator opf:role="aut">Jane Author</dc:creator>
        <meta name="cover" content="cover-img"/>
      </metadata>
      <manifest>
        <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
        <item id="chapter2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
        <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
        <item id="cover-img" href="images/cover.jpg" media-type="image/jpeg"/>
      </manifest>
      <spine toc="ncx">
        <itemref idref="chapter1"/>
        <itemref idref="chapter2"/>
      </spine>
    </package>
    """

    static let epub3OPF = """
    <?xml version="1.0" encoding="UTF-8"?>
    <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
      <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>Modern Book</dc:title>
        <dc:creator>John Writer</dc:creator>
      </metadata>
      <manifest>
        <item id="chapter1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
        <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
        <item id="cover-image" href="cover.png" media-type="image/png" properties="cover-image"/>
      </manifest>
      <spine>
        <itemref idref="chapter1"/>
      </spine>
    </package>
    """

    static let opfMissingTitle = """
    <?xml version="1.0" encoding="UTF-8"?>
    <package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="uid">
      <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
      </metadata>
      <manifest>
        <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
      </manifest>
      <spine>
        <itemref idref="chapter1"/>
      </spine>
    </package>
    """

    static let opfEmptySpine = """
    <?xml version="1.0" encoding="UTF-8"?>
    <package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="uid">
      <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>No Spine Book</dc:title>
      </metadata>
      <manifest>
        <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
      </manifest>
      <spine>
      </spine>
    </package>
    """
}
