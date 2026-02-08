// ABOUTME: Displays current sentence text with word-level highlighting.
// ABOUTME: Uses AttributedString to highlight the currently spoken word range.

import SwiftUI

struct HighlightedTextView: View {
    let text: String
    let highlightRange: Range<String.Index>?

    @AppStorage("showTextHighlighting") private var showHighlighting = true

    var body: some View {
        if showHighlighting {
            Text(attributedText)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(minHeight: 80)
                .animation(.easeInOut(duration: 0.1), value: highlightRange?.lowerBound)
        } else {
            Text(text)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(minHeight: 80)
        }
    }

    private var attributedText: AttributedString {
        var attributed = AttributedString(text)

        guard let range = highlightRange else { return attributed }

        // Convert String.Index range to AttributedString range
        let startOffset = text.distance(from: text.startIndex, to: range.lowerBound)
        let endOffset = text.distance(from: text.startIndex, to: range.upperBound)

        let attrStart = attributed.index(attributed.startIndex, offsetByCharacters: startOffset)
        let attrEnd = attributed.index(attributed.startIndex, offsetByCharacters: endOffset)

        attributed[attrStart..<attrEnd].backgroundColor = .accentColor.opacity(0.3)
        attributed[attrStart..<attrEnd].foregroundColor = .primary

        return attributed
    }
}
