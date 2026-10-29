import Foundation
import OSLog

nonisolated enum Log {
    // Unbundled runs (`swift test`) have no bundle identifier.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "unbundled"

    static let notes = Logger(subsystem: subsystem, category: "notes")
}
