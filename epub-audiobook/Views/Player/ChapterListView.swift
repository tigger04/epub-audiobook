// ABOUTME: Chapter list view for navigating between chapters during playback.
// ABOUTME: Highlights the current chapter and allows tap-to-jump.

import SwiftUI

struct ChapterListView: View {
    let coordinator: PlaybackCoordinator
    let chapters: [Chapter]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                Button {
                    coordinator.jumpToChapter(index)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chapter.title)
                                .font(.body)
                                .fontWeight(index == coordinator.currentChapterIndex ? .bold : .regular)

                            Text("\(chapter.sentences.count) sentences")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        chapterStatus(for: index)
                    }
                }
                .listRowBackground(
                    index == coordinator.currentChapterIndex
                        ? Color.accentColor.opacity(0.1)
                        : Color.clear
                )
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chapterStatus(for index: Int) -> some View {
        if index < coordinator.currentChapterIndex {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if index == coordinator.currentChapterIndex {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(Color.accentColor)
        }
    }
}
