// ABOUTME: Extracts readable text from EPUB XHTML chapter files.
// ABOUTME: Strips HTML tags, splits into sentences via NLTokenizer, falls back to regex for malformed HTML.

import Foundation
import NaturalLanguage

/// Extracts readable text from XHTML, splitting into sentences for TTS consumption.
enum XHTMLTextExtractor {

    /// Extract sentences from XHTML data.
    /// - Parameter data: The raw XHTML data from a chapter file.
    /// - Returns: An array of sentence strings, in reading order.
    static func extract(_ data: Data) -> [String] {
        guard !data.isEmpty else { return [] }

        // Try XMLParser first for well-formed XHTML
        let delegate = XHTMLXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true

        if parser.parse() {
            return splitIntoSentences(delegate.textBlocks)
        }

        // Fallback: regex-based tag stripping for malformed HTML
        return extractWithRegexFallback(data)
    }

    // MARK: - Sentence Splitting

    /// Splits text blocks into individual sentences using NLTokenizer.
    private static func splitIntoSentences(_ blocks: [String]) -> [String] {
        var sentences: [String] = []

        for block in blocks {
            let collapsed = collapseWhitespace(block)
            guard !collapsed.isEmpty else { continue }

            let tokenizer = NLTokenizer(unit: .sentence)
            tokenizer.string = collapsed

            var blockSentences: [String] = []
            tokenizer.enumerateTokens(in: collapsed.startIndex..<collapsed.endIndex) { range, _ in
                let sentence = String(collapsed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    blockSentences.append(sentence)
                }
                return true
            }

            // If NLTokenizer produced no sentences but block has text, use the block as-is
            if blockSentences.isEmpty {
                sentences.append(collapsed)
            } else {
                sentences.append(contentsOf: blockSentences)
            }
        }

        return sentences
    }

    // MARK: - Regex Fallback

    /// Extracts text from malformed HTML by stripping tags with a regex.
    private static func extractWithRegexFallback(_ data: Data) -> [String] {
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        // Remove script and style blocks
        var cleaned = html
        if let scriptRegex = try? NSRegularExpression(pattern: "<(script|style)[^>]*>.*?</\\1>", options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            cleaned = scriptRegex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }

        // Strip all HTML tags
        if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            cleaned = tagRegex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: " ")
        }

        // Decode common HTML entities
        cleaned = decodeHTMLEntities(cleaned)

        let collapsed = collapseWhitespace(cleaned)
        guard !collapsed.isEmpty else { return [] }

        return splitIntoSentences([collapsed])
    }

    // MARK: - Helpers

    /// Collapses runs of whitespace into single spaces and trims.
    private static func collapseWhitespace(_ text: String) -> String {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Decodes common HTML entities.
    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&nbsp;", " "),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }
}

// MARK: - XHTML XML Delegate

/// Elements whose text content should be excluded (not visible to reader).
private let excludedElements: Set<String> = ["script", "style", "head"]

/// Block-level elements that create paragraph boundaries.
private let blockElements: Set<String> = [
    "p", "div", "h1", "h2", "h3", "h4", "h5", "h6",
    "blockquote", "section", "article", "li", "dt", "dd",
    "tr", "caption", "figcaption",
]

private final class XHTMLXMLDelegate: NSObject, XMLParserDelegate {

    /// Text blocks separated by block-level element boundaries.
    var textBlocks: [String] = []

    private var currentText = ""
    private var excludeDepth = 0
    private var inBody = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String]
    ) {
        let name = elementName.lowercased()

        if name == "body" {
            inBody = true
        }

        if excludedElements.contains(name) {
            excludeDepth += 1
        }

        // Block elements flush the current text as a separate block
        if blockElements.contains(name) {
            flushCurrentText()
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let name = elementName.lowercased()

        if excludedElements.contains(name), excludeDepth > 0 {
            excludeDepth -= 1
        }

        if name == "body" {
            flushCurrentText()
            inBody = false
        }

        // Block elements also flush after their content
        if blockElements.contains(name) {
            flushCurrentText()
        }

        // Line breaks create paragraph boundaries
        if name == "br" {
            flushCurrentText()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inBody, excludeDepth == 0 else { return }
        currentText += string
    }

    private func flushCurrentText() {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            textBlocks.append(trimmed)
        }
        currentText = ""
    }
}
