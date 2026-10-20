import Testing

@testable import AppCore

@Test func greetStoresGreeting() {
    let model = AppModel()
    model.name = " Ada "
    model.greet()
    #expect(model.greeting?.contains("Ada") == true)
    #expect(model.errorMessage == nil)
}

@Test func greetRejectsBlankName() {
    let model = AppModel()
    model.name = "  "
    model.greet()
    #expect(model.greeting == nil)
    #expect(model.errorMessage != nil)
}
