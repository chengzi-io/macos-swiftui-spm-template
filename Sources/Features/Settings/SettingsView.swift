import Platform
import SwiftUI

public struct SettingsView: View {
    private let updater: any UpdaterService

    public init(updater: any UpdaterService) {
        self.updater = updater
    }

    public var body: some View {
        Form {
            Toggle(
                isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                )
            ) {
                Text("Automatically check for updates", bundle: .module)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

#Preview {
    SettingsView(updater: MockUpdaterService())
}
