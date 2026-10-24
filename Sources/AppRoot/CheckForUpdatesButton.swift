import Platform
import SwiftUI

/// A view of its own, as in Sparkle's SwiftUI setup guide, which needs one for the
/// disabled state to refresh before macOS 12.
struct CheckForUpdatesButton: View {
    let updater: any UpdaterService

    var body: some View {
        Button {
            updater.checkForUpdates()
        } label: {
            Text("Check for Updates…", bundle: .module)
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
