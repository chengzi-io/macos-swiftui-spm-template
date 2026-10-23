import Services
import SwiftUI

/// A view, not inline command content: commands only refresh through an observed view.
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
