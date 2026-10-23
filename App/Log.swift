import Foundation
import OSLog

nonisolated enum Log {
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "unbundled", category: "app")
}
