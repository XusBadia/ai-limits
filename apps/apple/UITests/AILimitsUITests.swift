import XCTest

@MainActor
final class AILimitsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDashboardShowsProvidersAndOpensDetails() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["AI Limits"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Claude"].exists)
        XCTAssertTrue(app.staticTexts["Codex"].exists)

        app.staticTexts["Claude"].tap()
        XCTAssertTrue(app.navigationBars["Claude"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Limits"].exists)
        XCTAssertTrue(app.staticTexts["Freshness"].exists)
    }

    func testEmptyStateExplainsMacConnection() {
        let app = XCUIApplication()
        app.launchArguments = ["--empty-preview"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Connect your Mac"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Check again"].exists)
    }
}
