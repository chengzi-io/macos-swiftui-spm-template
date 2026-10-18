import Foundation
import OSLog

nonisolated public enum Log {
    // Unbundled runs (Xcode Run, `swift run`) have no bundle identifier.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "unbundled"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
}
