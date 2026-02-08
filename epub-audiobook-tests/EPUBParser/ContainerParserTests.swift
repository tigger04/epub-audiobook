// ABOUTME: Unit tests for ContainerParser which extracts the OPF rootfile path from container.xml.
// ABOUTME: Tests valid XML, missing rootfile, malformed XML, and multiple rootfile scenarios.

import XCTest
@testable import epub_audiobook

final class ContainerParserTests: XCTestCase {

    // MARK: - Valid XML

    func test_containerParser_validXML_returnsOPFPath() throws {
        // Arrange
        let xmlString = """
        <?xml version="1.0"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        let xml = Data(xmlString.utf8)

        // Act
        let result = try ContainerParser.parse(xml)

        // Assert
        XCTAssertEqual(result.opfPath, "OEBPS/content.opf")
    }

    // MARK: - Different Path

    func test_containerParser_differentPath_returnsCorrectPath() throws {
        // Arrange
        let xmlString = """
        <?xml version="1.0"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile full-path="content/book.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        let xml = Data(xmlString.utf8)

        // Act
        let result = try ContainerParser.parse(xml)

        // Assert
        XCTAssertEqual(result.opfPath, "content/book.opf")
    }

    // MARK: - Missing Rootfile

    func test_containerParser_missingRootfile_throwsError() {
        // Arrange
        let xmlString = """
        <?xml version="1.0"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
          </rootfiles>
        </container>
        """
        let xml = Data(xmlString.utf8)

        // Act & Assert
        XCTAssertThrowsError(try ContainerParser.parse(xml)) { error in
            guard let containerError = error as? ContainerParserError else {
                XCTFail("Expected ContainerParserError, got \(error)")
                return
            }
            XCTAssertEqual(containerError, .rootfileNotFound)
        }
    }

    // MARK: - Malformed XML

    func test_containerParser_malformedXML_throwsError() {
        // Arrange
        let xmlString = """
        <?xml version="1.0"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf"
          </rootfiles>
        </container>
        """
        let xml = Data(xmlString.utf8)

        // Act & Assert
        XCTAssertThrowsError(try ContainerParser.parse(xml)) { error in
            guard let containerError = error as? ContainerParserError else {
                XCTFail("Expected ContainerParserError, got \(error)")
                return
            }
            if case .xmlParsingFailed = containerError {
                // Expected
            } else {
                XCTFail("Expected .xmlParsingFailed, got \(containerError)")
            }
        }
    }

    // MARK: - Empty Data

    func test_containerParser_emptyData_throwsError() {
        // Arrange
        let xml = Data()

        // Act & Assert
        XCTAssertThrowsError(try ContainerParser.parse(xml))
    }

    // MARK: - Rootfile Without full-path Attribute

    func test_containerParser_rootfileWithoutFullPath_throwsError() {
        // Arrange
        let xmlString = """
        <?xml version="1.0"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        let xml = Data(xmlString.utf8)

        // Act & Assert
        XCTAssertThrowsError(try ContainerParser.parse(xml)) { error in
            guard let containerError = error as? ContainerParserError else {
                XCTFail("Expected ContainerParserError, got \(error)")
                return
            }
            XCTAssertEqual(containerError, .rootfileNotFound)
        }
    }
}
