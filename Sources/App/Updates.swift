#if !APP_STORE
    import AppCore
    import Combine
    import Sparkle
    import SwiftUI

    /// Sparkle updater state for SwiftUI. Debug builds never start the updater:
    /// they carry no feed URL or public key.
    final class Updates: ObservableObject {
        @Published private(set) var canCheckForUpdates = false
        @Published var automaticallyChecksForUpdates: Bool {
            didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
        }

        private let controller: SPUStandardUpdaterController

        init() {
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
            controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        }

        func checkForUpdates() {
            controller.checkForUpdates(nil)
        }
    }

    /// A view, not inline command content: commands only refresh through an observed view.
    struct CheckForUpdatesView: View {
        @ObservedObject var updates: Updates

        var body: some View {
            CheckForUpdatesButton(canCheck: updates.canCheckForUpdates, action: updates.checkForUpdates)
        }
    }
#endif
