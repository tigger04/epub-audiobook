// ABOUTME: Parses OPF (Open Packaging Format) package documents for EPUB metadata.
// ABOUTME: Extracts title, author, cover, manifest items, and spine reading order.

import Foundation

/// Metadata extracted from the OPF package document.
struct OPFMetadata: Equatable, Sendable {
    var title: String?
    var author: String?
    /// The manifest item ID referencing the cover image.
    var coverImageID: String?
}

/// A single item from the OPF manifest.
struct ManifestItem: Equatable, Sendable {
    let id: String
    let href: String
    let mediaType: String
    var properties: String?
}

/// Result of parsing an OPF package document.
struct OPFResult: Equatable, Sendable {
    let metadata: OPFMetadata
    let manifest: [ManifestItem]
    /// Ordered list of manifest item IDs from the spine.
    let spineItemRefs: [String]

    /// Resolves the cover image href by looking up the cover ID in the manifest.
    var coverImageHref: String? {
        guard let coverID = metadata.coverImageID else { return nil }
        return manifest.first { $0.id == coverID }?.href
    }
}

/// Errors that can occur when parsing an OPF document.
enum OPFParserError: Error, Equatable {
    case xmlParsingFailed(String)
}

/// Parses OPF package documents to extract metadata, manifest, and spine.
enum OPFParser {

    /// Parse an OPF package document.
    /// - Parameter data: The raw XML data of the OPF file.
    /// - Returns: An `OPFResult` with metadata, manifest, and spine.
    /// - Throws: `OPFParserError` if XML parsing fails.
    static func parse(_ data: Data) throws -> OPFResult {
        let delegate = OPFXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true

        guard parser.parse() else {
            let errorDescription = parser.parserError?.localizedDescription ?? "Unknown XML error"
            throw OPFParserError.xmlParsingFailed(errorDescription)
        }

        return OPFResult(
            metadata: delegate.metadata,
            manifest: delegate.manifestItems,
            spineItemRefs: delegate.spineItemRefs
        )
    }
}

// MARK: - XML Delegate

private final class OPFXMLDelegate: NSObject, XMLParserDelegate {

    var metadata = OPFMetadata()
    var manifestItems: [ManifestItem] = []
    var spineItemRefs: [String] = []

    private var currentElement = ""
    private var currentText = ""
    private var inMetadata = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String]
    ) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "metadata":
            inMetadata = true

        case "meta" where inMetadata:
            // EPUB 2 cover: <meta name="cover" content="cover-img"/>
            if attributeDict["name"] == "cover",
               let content = attributeDict["content"] {
                metadata.coverImageID = content
            }

        case "item":
            if let id = attributeDict["id"],
               let href = attributeDict["href"],
               let mediaType = attributeDict["media-type"] {
                var item = ManifestItem(id: id, href: href, mediaType: mediaType)
                item.properties = attributeDict["properties"]

                // EPUB 3 cover: <item properties="cover-image" .../>
                if let properties = item.properties,
                   properties.contains("cover-image") {
                    metadata.coverImageID = id
                }

                manifestItems.append(item)
            }

        case "itemref":
            if let idref = attributeDict["idref"] {
                spineItemRefs.append(idref)
            }

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        if elementName == "metadata" {
            inMetadata = false
        }

        guard inMetadata else { return }

        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch elementName {
        case "title":
            metadata.title = trimmed
        case "creator":
            metadata.author = trimmed
        default:
            break
        }

        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
}
