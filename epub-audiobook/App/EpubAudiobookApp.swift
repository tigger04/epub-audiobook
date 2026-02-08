// ABOUTME: Main entry point for the epub-audiobook iOS app.
// ABOUTME: Configures SwiftUI app lifecycle and SwiftData model container.

import SwiftUI

@main
struct EpubAudiobookApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
    }
}
