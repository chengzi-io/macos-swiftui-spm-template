import GreetingFeature
import SettingsFeature
import SwiftUI

/// Every window, menu command and the Settings scene. The app target's `@main`
/// only builds the services and hands them over.
public struct AppScenes: Scene {
    private let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some Scene {
        WindowGroup {
            GreetingView(model: model.greeting)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesButton(updater: model.updater)
            }
        }
        Settings {
            SettingsView(updater: model.updater)
        }
    }
}
