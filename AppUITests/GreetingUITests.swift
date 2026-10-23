import XCTest

@MainActor
final class GreetingUITests: XCTestCase {
    func testGreetsByName() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTING"] = "1"
        // A fresh launch in English, not the windows of the last session.
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(en)"]
        app.launch()

        let name = app.textFields["greeting.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.click()
        name.typeText("Ada")
        app.buttons["greeting.greet"].click()

        let result = app.staticTexts["greeting.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        // On macOS a text's string is its accessibility value; its label is empty.
        let greeting = result.value as? String ?? ""
        XCTAssertTrue(greeting.contains("Ada"), "greeting was \(greeting)")
    }
}
