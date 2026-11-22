import Platform
import SwiftUI

/// The Settings window: one tab per pane in the toolbar, as in Safari or TextEdit. General
/// is the first; an app's next pane is another tab after it.
public struct SettingsView: View {
    private let model: SettingsModel

    public init(model: SettingsModel) {
        self.model = model
    }

    public var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem {
                    // `Label(_:systemImage:)` takes a `LocalizedStringKey` and would look in
                    // the main bundle; the bundle goes through `Text` instead.
                    Label {
                        Text("General", bundle: .module)
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
        }
    }
}

#Preview {
    SettingsView(
        model: SettingsModel(
            updater: MockUpdaterService(),
            preferences: MockPreferencesStore(),
            appearance: MockAppearanceService()
        ))
}
