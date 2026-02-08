// ABOUTME: Card view displaying a book's cover, title, author, and progress.
// ABOUTME: Used in the LibraryView grid layout.

import SwiftUI

struct BookCardView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            coverImage
                .frame(maxWidth: .infinity)
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(book.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            if let author = book.author {
                Text(author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let position = book.readingPosition,
               let chapters = book.chapters, !chapters.isEmpty {
                let progress = Double(position.chapterIndex) / Double(chapters.count)
                ProgressView(value: progress)
                    .tint(.accentColor)
            }
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let data = book.coverImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                Image(systemName: "book.closed.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
