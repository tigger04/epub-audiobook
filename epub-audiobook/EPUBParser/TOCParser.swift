// ABOUTME: Parses EPUB table of contents from NCX (EPUB 2) and nav (EPUB 3) documents.
// ABOUTME: Returns a flat list of TOCEntry items with depth information for nested chapters.

import Foundation

/// A single entry in the table of contents.
struct TOCEntry: Equatable, Sendable {
    let title: String
    let href: String
    let playOrder: Int?
    let depth: Int
}

/// Errors that can occur when parsing TOC documents.
enum TOCParserError: Error, Equatable {
    case xmlParsingFailed(String)
}

/// Parses EPUB 2 NCX and EPUB 3 nav documents to build a chapter table of contents.
enum TOCParser {

    /// Parse an EPUB 2 NCX document.
    /// - Parameter data: The raw XML data of the .ncx file.
    /// - Returns: A flat list of `TOCEntry` items in reading order.
    /// - Throws: `TOCParserError` if XML parsing fails.
    static func parseNCX(_ data: Data) throws -> [TOCEntry] {
        let delegate = NCXXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true

        guard parser.parse() else {
            let errorDescription = parser.parserError?.localizedDescription ?? "Unknown XML error"
            throw TOCParserError.xmlParsingFailed(errorDescription)
        }

        return delegate.entries
    }

    /// Parse an EPUB 3 nav document.
    /// - Parameter data: The raw XML data of the nav.xhtml file.
    /// - Returns: A flat list of `TOCEntry` items in reading order.
    /// - Throws: `TOCParserError` if XML parsing fails.
    static func parseNav(_ data: Data) throws -> [TOCEntry] {
        let delegate = NavXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        // Do not process namespaces — we need to match epub:type as a qualified attribute name
        parser.shouldProcessNamespaces = false

        guard parser.parse() else {
            let errorDescription = parser.parserError?.localizedDescription ?? "Unknown XML error"
            throw TOCParserError.xmlParsingFailed(errorDescription)
        }

        return delegate.entries
    }
}

// MARK: - NCX NavPoint State

/// Tracks the state of a single navPoint during parsing.
private struct NavPointState {
    var label: String = ""
    var src: String = ""
    var playOrder: Int?
    var depth: Int
}

// MARK: - NCX XML Delegate

private final class NCXXMLDelegate: NSObject, XMLParserDelegate {

    var entries: [TOCEntry] = []

    private var navPointStack: [NavPointState] = []
    private var currentText = ""
    private var inNavLabel = false
    private var inText = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String]
    ) {
        switch elementName {
        case "navPoint":
            let depth = navPointStack.count
            var state = NavPointState(depth: depth)
            if let orderStr = attributeDict["playOrder"] {
                state.playOrder = Int(orderStr)
            }
            navPointStack.append(state)

        case "navLabel":
            inNavLabel = true

        case "text" where inNavLabel:
            inText = true
            currentText = ""

        case "content":
            // Emit entry when we have both label and src — ensures parent appears before children
            if let src = attributeDict["src"], !navPointStack.isEmpty {
                navPointStack[navPointStack.count - 1].src = src
                let state = navPointStack[navPointStack.count - 1]
                if !state.label.isEmpty {
                    entries.append(TOCEntry(
                        title: state.label,
                        href: state.src,
                        playOrder: state.playOrder,
                        depth: state.depth
                    ))
                }
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
        switch elementName {
        case "text" where inText:
            let label = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !navPointStack.isEmpty {
                navPointStack[navPointStack.count - 1].label = label
            }
            inText = false

        case "navLabel":
            inNavLabel = false

        case "navPoint":
            navPointStack.removeLast()

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText {
            currentText += string
        }
    }
}

// MARK: - Nav XML Delegate

private final class NavXMLDelegate: NSObject, XMLParserDelegate {

    var entries: [TOCEntry] = []

    private var inTocNav = false
    private var olDepth = -1
    private var currentHref = ""
    private var currentText = ""
    private var inAnchor = false
    private var entryOrder = 0

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String]
    ) {
        switch elementName {
        case "nav":
            // Check for epub:type="toc" — attribute may appear with or without namespace prefix
            if attributeDict["epub:type"] == "toc" || attributeDict["type"] == "toc" {
                inTocNav = true
            }

        case "ol" where inTocNav:
            olDepth += 1

        case "a" where inTocNav:
            inAnchor = true
            currentHref = attributeDict["href"] ?? ""
            currentText = ""

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
        switch elementName {
        case "a" where inAnchor && inTocNav:
            let title = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty, !currentHref.isEmpty {
                entryOrder += 1
                entries.append(TOCEntry(
                    title: title,
                    href: currentHref,
                    playOrder: entryOrder,
                    depth: olDepth
                ))
            }
            inAnchor = false

        case "ol" where inTocNav:
            olDepth -= 1

        case "nav" where inTocNav:
            inTocNav = false

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inAnchor {
            currentText += string
        }
    }
}
