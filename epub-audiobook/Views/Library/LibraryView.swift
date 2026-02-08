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
        }
    }

    // MARK: - Actions

    private func openBook(_ book: Book) {
        let engine = SystemTTSEngine()
        let playbackCoordinator = PlaybackCoordinator(ttsEngine: engine, modelContext: modelContext)
        playbackCoordinator.loadBook(book)
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

    private func deleteBook(_ book: Book) {
        // Remove file from sandbox
        let fileURL = BookImportService.booksDirectory.appendingPathComponent(book.epubFilePath)
        try? FileManager.default.removeItem(at: fileURL)

        modelContext.delete(book)
        try? modelContext.save()
    }
}
