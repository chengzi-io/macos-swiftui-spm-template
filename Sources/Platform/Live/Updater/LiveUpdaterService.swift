import Foundation
import Observation
import Platform
import Sparkle

/// Sparkle's standard updater. Debug builds never start it, so a build under development
/// never offers to replace itself with the latest release.
@MainActor
@Observable
public final class LiveUpdaterService: UpdaterService {
    public private(set) var canCheckForUpdates = false
    public var automaticallyChecksForUpdates: Bool {
        didSet {
            // Only a change from the toggle: writing Sparkle's own value back would
            // reschedule its checks for nothing.
            guard controller.updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates
            else { return }
            controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
    @ObservationIgnored private var automaticChecksObservation: NSKeyValueObservation?

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
        // Sparkle changes both on the main thread. It sets automaticallyChecksForUpdates
        // itself when the user answers its question on the second launch.
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) {
            [weak self] updater, _ in
            MainActor.assumeIsolated {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
        automaticChecksObservation = controller.updater.observe(\.automaticallyChecksForUpdates, options: [.new]) {
            [weak self] updater, _ in
            MainActor.assumeIsolated {
                self?.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
            }
        }
    }

    public func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
