// ABOUTME: Individual bookmark row displaying label, chapter, and timestamp.
// ABOUTME: Used in BookmarksListView.

import SwiftUI

struct BookmarkRowView: View {
    let bookmark: Bookmark
    let chapterTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bookmark.label)
                .font(.body)

            HStack {
                if let chapterTitle {
                    Text(chapterTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Ch \(bookmark.chapterIndex + 1), Sentence \(bookmark.sentenceIndex + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(bookmark.createdAt, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
