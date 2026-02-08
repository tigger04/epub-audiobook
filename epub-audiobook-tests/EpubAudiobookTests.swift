// ABOUTME: Root test file for epub-audiobook unit and integration tests.
// ABOUTME: Verifies basic app infrastructure is wired up correctly.

import XCTest
@testable import epub_audiobook

final class EpubAudiobookTests: XCTestCase {

    func test_libraryView_exists() {
        // Arrange & Act
        let view = LibraryView()

        // Assert — LibraryView should be constructable without errors
        XCTAssertNotNil(view)
    }
}
