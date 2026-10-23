import Foundation
import Observation
import Services
import Sparkle

/// Sparkle's standard updater. Debug builds never start it: they carry no public key.
@MainActor
@Observable
public final class LiveUpdaterService: UpdaterService {
    public private(set) var canCheckForUpdates = false
    public var automaticallyChecksForUpdates: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
    }

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    public init() {
        #if DEBUG
            let startsUpdater = false
        #else
            let startsUpdater = true
        #endif
        controller = SPUStandardUpdaterController(
            startingUpdater: startsUpdater,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        // Sparkle changes canCheckForUpdates on the main thread.
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) {
            [weak self] updater, _ in
            MainActor.assumeIsolated {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    public func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
