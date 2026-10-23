import XCTest

@MainActor
final class GreetingUITests: XCTestCase {
    func testGreetsByName() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)"]
        app.launch()

        let name = app.textFields["greeting.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.click()
        name.typeText("Ada")
        app.buttons["greeting.greet"].click()

        let result = app.staticTexts["greeting.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("Ada"), "greeting was \(result.label)")
    }
}
