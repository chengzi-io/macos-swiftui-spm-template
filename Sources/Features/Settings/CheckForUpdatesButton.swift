import Platform
import SwiftUI

/// The app menu's item and the Updates pane's button. A view of its own, as in Sparkle's
/// SwiftUI setup guide, which needs one for the disabled state to refresh before macOS 12.
public struct CheckForUpdatesButton: View {
    private let updater: any UpdaterService

    public init(updater: any UpdaterService) {
        self.updater = updater
    }

    public var body: some View {
        Button {
            updater.checkForUpdates()
        } label: {
            Text("Check for Updates…", bundle: .module)
        }
        .disabled(!updater.canCheckForUpdates)
    }
}

#Preview {
    CheckForUpdatesButton(updater: MockUpdaterService())
        .padding()
}
