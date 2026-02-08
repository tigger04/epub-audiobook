// ABOUTME: Main now-playing screen showing book info, current sentence, progress, and controls.
// ABOUTME: Driven by PlaybackCoordinator, presented as a sheet from LibraryView.

import SwiftUI

struct PlayerView: View {
    let coordinator: PlaybackCoordinator

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingChapters = false
    @State private var showingBookmarks = false
    @State private var showingSleepTimer = false
    @State private var sleepTimerService: SleepTimerService?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                bookInfoSection

                Spacer()

                sentenceSection

                Spacer()

                progressSection

                PlaybackControlsView(coordinator: coordinator)
                    .padding(.vertical)

                SpeedControlView(coordinator: coordinator)

                if let sleepTimerService, sleepTimerService.isActive {
                    Text("Sleep: \(sleepTimerService.formattedRemaining)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            showingSleepTimer = true
                        } label: {
                            Image(systemName: "moon.zzz")
                        }
                        Button {
                            showingBookmarks = true
                        } label: {
                            Image(systemName: "bookmark")
                        }
                        Button {
                            showingChapters = true
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                }
            }
            .onAppear {
                if sleepTimerService == nil {
                    sleepTimerService = SleepTimerService(coordinator: coordinator)
                }
            }
            .sheet(isPresented: $showingSleepTimer) {
                if let sleepTimerService {
                    SleepTimerView(timerService: sleepTimerService)
                }
            }
            .sheet(isPresented: $showingChapters) {
                if let chapter = coordinator.currentChapter,
                   let book = chapter.book,
                   let chapters = book.chapters?.sorted(by: { $0.spineIndex < $1.spineIndex }) {
                    ChapterListView(coordinator: coordinator, chapters: chapters)
                }
            }
            .sheet(isPresented: $showingBookmarks) {
                if let chapter = coordinator.currentChapter,
                   let book = chapter.book {
                    BookmarksListView(
                        coordinator: coordinator,
                        bookmarkService: BookmarkService(modelContext: modelContext),
                        book: book
                    )
                }
            }
        }
    }

    // MARK: - Sections

    private var bookInfoSection: some View {
        VStack(spacing: 8) {
            if let chapter = coordinator.currentChapter {
                Text(chapter.title)
                    .font(.headline)
            }

            Text("Chapter \(coordinator.currentChapterIndex + 1)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var sentenceSection: some View {
        Group {
            if let sentence = coordinator.currentSentenceText {
                Text(sentence)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(minHeight: 80)
            } else {
                Text("Ready to play")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 80)
            }
        }
    }

    private var progressSection: some View {
        VStack(spacing: 4) {
            ProgressView(value: coordinator.chapterProgress)
                .progressViewStyle(.linear)

            HStack {
                Text("Sentence \(coordinator.currentSentenceIndex + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(coordinator.bookProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
