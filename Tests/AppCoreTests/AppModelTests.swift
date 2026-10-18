import Testing

@testable import AppCore

private struct StubGreeter: Greeter {
    let result: Result<String, GreeterError>

    func greet(_ name: String) async throws -> String {
        try result.get()
    }
}

@Test func greetStoresGreeting() async {
    let model = AppModel(greeter: StubGreeter(result: .success("hi")))
    await model.greet()
    #expect(model.greeting == "hi")
    #expect(model.errorMessage == nil)
}

@Test func greetSurfacesError() async {
    let model = AppModel(greeter: StubGreeter(result: .failure(.emptyName)))
    await model.greet()
    #expect(model.greeting == nil)
    #expect(model.errorMessage != nil)
}

@Test func localGreeterRejectsBlankName() async {
    await #expect(throws: GreeterError.emptyName) {
        try await LocalGreeter().greet("  ")
    }
}
