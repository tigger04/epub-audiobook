// ABOUTME: Main library screen displaying imported books in a grid layout.
// ABOUTME: Placeholder view for initial scaffolding — will be expanded in Issue #13.

import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Books Yet",
                systemImage: "book.closed",
                description: Text("Import an EPUB file to get started.")
            )
            .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryView()
}
