import Platform
import SwiftUI

/// The app menu's item and the button in Settings' Updates section: one view for both.
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
