import Foundation
import Platform
import SwiftUI

struct UpdatesSettingsView: View {
    let updater: any UpdaterService
    /// `CFBundleShortVersionString (CFBundleVersion)`, which scripts/build-app.sh writes.
    var version = Self.bundleVersion

    var body: some View {
        Form {
            LabeledContent {
                Text(version)
                    .textSelection(.enabled)
            } label: {
                Text("Version:", bundle: .module)
            }
            Toggle(
                isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                )
            ) {
                Text("Automatically check for updates", bundle: .module)
            }
            CheckForUpdatesButton(updater: updater)
        }
        .padding(20)
        .frame(width: 450)
    }

    private static var bundleVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        return "\(version) (\(build))"
    }
}

#Preview {
    UpdatesSettingsView(updater: MockUpdaterService())
}
