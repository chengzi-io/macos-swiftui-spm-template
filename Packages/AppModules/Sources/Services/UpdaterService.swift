import Observation

/// Checks for and installs app updates. Implementations are `@Observable`, so a view
/// that reads `canCheckForUpdates` refreshes when it changes.
@MainActor
public protocol UpdaterService: AnyObject, Observable {
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    func checkForUpdates()
}

/// Stands in for Sparkle in previews, tests and UI test launches (`UI_TESTING=1`).
@MainActor
@Observable
public final class MockUpdaterService: UpdaterService {
    public var canCheckForUpdates: Bool
    public var automaticallyChecksForUpdates: Bool
    public private(set) var checkCount = 0

    public init(canCheckForUpdates: Bool = true, automaticallyChecksForUpdates: Bool = true) {
        self.canCheckForUpdates = canCheckForUpdates
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    public func checkForUpdates() {
        checkCount += 1
    }
}
