import XCTest

@MainActor
final class NotesUITests: XCTestCase {
    func testSavesTheNote() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTING"] = "1"
        // A fresh launch in English, not the windows of the last session.
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(en)"]
        app.launch()

        let text = app.textViews["notes.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        text.click()
        text.typeText("Pomelo")

        // On macOS a text's string is its accessibility value; its label is empty.
        let status = app.staticTexts["notes.status"]
        XCTAssertEqual(status.value as? String, "Edited")
        app.buttons["notes.save"].click()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Saved'"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
    }
}
