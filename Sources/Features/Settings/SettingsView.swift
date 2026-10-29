import Platform
import SwiftUI

/// The Settings window: one tab per pane in the toolbar, as in Safari or TextEdit. An
/// app's own settings go in a General tab before Updates.
public struct SettingsView: View {
    private let updater: any UpdaterService

    public init(updater: any UpdaterService) {
        self.updater = updater
    }

    public var body: some View {
        TabView {
            UpdatesSettingsView(updater: updater)
                .tabItem {
                    // `Label(_:systemImage:)` takes a `LocalizedStringKey` and would look in
                    // the main bundle; the bundle goes through `Text` instead.
                    Label {
                        Text("Updates", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
        }
    }
}

#Preview {
    SettingsView(updater: MockUpdaterService())
}
