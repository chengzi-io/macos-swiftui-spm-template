import XCTest

@MainActor
final class LaunchUITests: XCTestCase {
    func testOpensAWindow() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTING"] = "1"
        // A fresh launch in English, not the windows of the last session.
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(en)"]
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }
}
