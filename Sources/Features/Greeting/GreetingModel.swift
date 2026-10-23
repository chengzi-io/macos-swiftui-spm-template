import Foundation
import OSLog
import Observation

@Observable
public final class GreetingModel {
    public var name = ""
    public private(set) var greeting: String?
    public var errorMessage: String?

    private let greeter = Greeter()

    public init() {}

    public func greet() {
        do {
            greeting = try greeter.greet(name)
        } catch {
            Log.greeting.error("greet failed: \(String(describing: error), privacy: .public)")
            errorMessage = error.message
        }
    }
}
