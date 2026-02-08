// ABOUTME: Parses META-INF/container.xml to extract the OPF rootfile path.
// ABOUTME: First step in EPUB parsing — every EPUB contains this file to locate the package document.

import Foundation

/// Result of parsing a container.xml file.
struct ContainerResult: Equatable, Sendable {
    /// Path to the OPF package document, relative to the EPUB root.
    let opfPath: String
}

/// Errors that can occur when parsing container.xml.
enum ContainerParserError: Error, Equatable {
    case rootfileNotFound
    case xmlParsingFailed(String)
}

/// Parses container.xml to extract the OPF rootfile path.
enum ContainerParser {

    /// Parse container.xml data and extract the OPF rootfile path.
    /// - Parameter data: The raw XML data from META-INF/container.xml.
    /// - Returns: A `ContainerResult` containing the OPF path.
    /// - Throws: `ContainerParserError` if parsing fails or the rootfile is missing.
    static func parse(_ data: Data) throws -> ContainerResult {
        let delegate = ContainerXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            let errorDescription = parser.parserError?.localizedDescription ?? "Unknown XML error"
            throw ContainerParserError.xmlParsingFailed(errorDescription)
        }

        guard let opfPath = delegate.opfPath else {
            throw ContainerParserError.rootfileNotFound
        }

        return ContainerResult(opfPath: opfPath)
    }
}

// MARK: - XML Delegate

private final class ContainerXMLDelegate: NSObject, XMLParserDelegate {

    var opfPath: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String]
    ) {
        if elementName == "rootfile" {
            if let fullPath = attributeDict["full-path"] {
                opfPath = fullPath
            }
        }
    }
}
