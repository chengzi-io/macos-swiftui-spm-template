import Foundation

public protocol Greeter {
    func greet(_ name: String) async throws -> String
}

public enum GreeterError: Error {
    case emptyName

    // Error types are nonisolated (Error is Sendable), so `LocalizedError` cannot
    // read `Bundle.module`, which the package's default isolation puts on MainActor.
    @MainActor var message: String {
        switch self {
        case .emptyName: String(localized: "Please enter a name.", bundle: .module)
        }
    }
}

public struct LocalGreeter: Greeter {
    public init() {}

    public func greet(_ name: String) async throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GreeterError.emptyName }
        return String(localized: "Hello, \(trimmed)!", bundle: .module)
    }
}
