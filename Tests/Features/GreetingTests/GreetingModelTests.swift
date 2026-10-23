import Testing

@testable import GreetingFeature

@Test func greetStoresGreeting() {
    let model = GreetingModel()
    model.name = " Ada "
    model.greet()
    #expect(model.greeting?.contains("Ada") == true)
    #expect(model.errorMessage == nil)
}

@Test func greetRejectsBlankName() {
    let model = GreetingModel()
    model.name = "  "
    model.greet()
    #expect(model.greeting == nil)
    #expect(model.errorMessage != nil)
}
