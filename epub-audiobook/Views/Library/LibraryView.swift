// ABOUTME: Main library screen displaying imported books in a responsive grid layout.
// ABOUTME: Supports import from Files app, tap to play, and swipe/long-press delete.

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.importDate, order: .reverse) private var books: [Book]

    @State private var showingImporter = false
    @State private var showingPlayer = false
    @State private var selectedBook: Book?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingError = false

    @State private var coordinator: PlaybackCoordinator?
    @State private var showingSettings = false
    @State private var showingResumePrompt = false
    @State private var resumeBook: Book?
    @State private var pendingImportURL: URL?

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView(
                        "No Books Yet",
                        systemImage: "book.closed",
                        description: Text("Import an EPUB file to get started.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(books) { book in
                                BookCardView(book: book)
                                    .onTapGesture {
                                        openBook(book)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteBook(book)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(isImporting)
                }
            }
            .overlay {
                if isImporting {
                    ProgressView("Importing…")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.epub],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .sheet(isPresented: $showingPlayer) {
                if let coordinator {
                    PlayerView(coordinator: coordinator)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "An unknown error occurred.")
            }
            .alert("Continue Reading?", isPresented: $showingResumePrompt) {
                Button("Resume") {
                    if let book = resumeBook {
                        openBook(book)
                    }
                }
                Button("Library", role: .cancel) {
                    resumeBook = nil
                }
            } message: {
                if let book = resumeBook {
                    Text("Continue reading \"\(book.title)\"?")
                }
            }
            .onAppear {
                checkForResume()
            }
            .onOpenURL { url in
                importFromURL(url)
            }
            .onChange(of: pendingImportURL) { _, url in
                guard let url else { return }
                pendingImportURL = nil
                importFromURL(url)
            }
        }
    }

    // MARK: - Actions

    private func openBook(_ book: Book) {
        let engine = SystemTTSEngine()
        let playbackCoordinator = PlaybackCoordinator(ttsEngine: engine, modelContext: modelContext)
        playbackCoordinator.loadBook(book)

        let nowPlaying = NowPlayingService(coordinator: playbackCoordinator)
        nowPlaying.configure()
        let chapters = (book.chapters ?? []).sorted { $0.spineIndex < $1.spineIndex }
        nowPlaying.updateNowPlayingInfo(
            bookTitle: book.title,
            chapterTitle: chapters.first?.title ?? "Chapter 1",
            chapterIndex: 0,
            totalChapters: chapters.count,
            coverImageData: book.coverImageData
        )

        coordinator = playbackCoordinator
        selectedBook = book
        showingPlayer = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true
            Task {
                do {
                    let service = BookImportService(modelContext: modelContext)
                    _ = try await service.importBook(from: url)
                } catch {
                    importError = error.localizedDescription
                    showingError = true
                }
                isImporting = false
            }
        case .failure(let error):
            importError = error.localizedDescription
            showingError = true
        }
    }

    private func checkForResume() {
        // Find the most recently updated reading position
        var descriptor = FetchDescriptor<ReadingPosition>(
            sortBy: [SortDescriptor(\ReadingPosition.lastUpdated, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let positions = try? modelContext.fetch(descriptor),
              let position = positions.first,
              let book = position.book else { return }

        // Don't offer resume if at the very start
        guard position.chapterIndex > 0 || position.sentenceIndex > 0 else { return }

        // Don't offer resume if at the end of the book
        let chapters = (book.chapters ?? []).sorted { $0.spineIndex < $1.spineIndex }
        if position.chapterIndex >= chapters.count - 1,
           let lastChapter = chapters.last,
           position.sentenceIndex >= lastChapter.sentences.count - 1 {
            return
        }

        resumeBook = book
        showingResumePrompt = true
    }

    private func importFromURL(_ url: URL) {
        guard url.pathExtension.lowercased() == "epub" else { return }
        isImporting = true
        Task {
            do {
                let service = BookImportService(modelContext: modelContext)
                let book = try await service.importBook(from: url)
                openBook(book)
            } catch {
                importError = error.localizedDescription
                showingError = true
            }
            isImporting = false
        }
    }

    private func deleteBook(_ book: Book) {
        // Remove file from sandbox
        let fileURL = BookImportService.booksDirectory.appendingPathComponent(book.epubFilePath)
        try? FileManager.default.removeItem(at: fileURL)

        modelContext.delete(book)
        try? modelContext.save()
    }
}
