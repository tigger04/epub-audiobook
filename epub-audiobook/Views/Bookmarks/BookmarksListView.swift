// ABOUTME: List view for bookmarks with swipe-to-delete and tap-to-jump.
// ABOUTME: Includes an "Add Bookmark" button to save the current position.

import SwiftUI

struct BookmarksListView: View {
    let coordinator: PlaybackCoordinator
    let bookmarkService: BookmarkService
    let book: Book

    @Environment(\.dismiss) private var dismiss
    @State private var bookmarks: [Bookmark] = []
    @State private var showingAddLabel = false
    @State private var newLabel = ""

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Tap + to bookmark the current position.")
                    )
                } else {
                    List {
                        ForEach(bookmarks, id: \.persistentModelID) { bookmark in
                            Button {
                                coordinator.jumpToChapter(bookmark.chapterIndex)
                                // Jump to specific sentence within the chapter
                                while coordinator.currentSentenceIndex < bookmark.sentenceIndex {
                                    coordinator.skipForward()
                                }
                                dismiss()
                            } label: {
                                BookmarkRowView(
                                    bookmark: bookmark,
                                    chapterTitle: chapterTitle(for: bookmark.chapterIndex)
                                )
                            }
                        }
                        .onDelete(perform: deleteBookmarks)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddLabel = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Add Bookmark", isPresented: $showingAddLabel) {
                TextField("Label", text: $newLabel)
                Button("Save") {
                    addBookmark()
                }
                Button("Cancel", role: .cancel) {
                    newLabel = ""
                }
            } message: {
                Text("Enter a label for this bookmark.")
            }
            .onAppear {
                refreshBookmarks()
            }
        }
    }

    private func addBookmark() {
        let label = newLabel.isEmpty ? "Bookmark" : newLabel
        _ = bookmarkService.createBookmark(
            label: label,
            chapterIndex: coordinator.currentChapterIndex,
            sentenceIndex: coordinator.currentSentenceIndex,
            for: book
        )
        newLabel = ""
        refreshBookmarks()
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        for index in offsets {
            bookmarkService.deleteBookmark(bookmarks[index])
        }
        refreshBookmarks()
    }

    private func refreshBookmarks() {
        bookmarks = bookmarkService.bookmarks(for: book)
    }

    private func chapterTitle(for index: Int) -> String? {
        let sorted = (book.chapters ?? []).sorted { $0.spineIndex < $1.spineIndex }
        guard index < sorted.count else { return nil }
        return sorted[index].title
    }
}
