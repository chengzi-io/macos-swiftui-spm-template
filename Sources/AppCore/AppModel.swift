import Foundation
import Observation

@Observable
public final class AppModel {
    public var name = ""
    public private(set) var greeting: String?
    public var errorMessage: String?

    private let greeter: any Greeter

    public init(greeter: any Greeter) {
        self.greeter = greeter
    }

    public func greet() async {
        do {
            greeting = try await greeter.greet(name)
        } catch let error as GreeterError {
            Log.ui.error("greet failed: \(String(describing: error), privacy: .public)")
            errorMessage = error.message
        } catch {
            Log.ui.error("greet failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
}
