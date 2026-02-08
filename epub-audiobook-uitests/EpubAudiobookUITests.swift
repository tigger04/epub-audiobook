// ABOUTME: Root UI test file for epub-audiobook end-to-end tests.
// ABOUTME: Verifies app launches and displays the library screen.

import XCTest

@MainActor
final class EpubAudiobookUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_appLaunch_showsLibraryTitle() throws {
        // Arrange
        let app = XCUIApplication()

        // Act
        app.launch()

        // Assert
        XCTAssertTrue(app.navigationBars["Library"].exists)
    }

    func test_appLaunch_showsEmptyState() throws {
        // Arrange
        let app = XCUIApplication()

        // Act
        app.launch()

        // Assert
        let emptyStateText = app.staticTexts["No Books Yet"]
        XCTAssertTrue(emptyStateText.exists)
    }
}
