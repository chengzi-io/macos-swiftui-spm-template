import DemoFeature
import NotesFeature
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
            NotesView(model: model.notes)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesButton(updater: model.updater)
            }
        }
        Window(Text(verbatim: "Demo"), id: "demo") {
            DemoView(model: model.demo)
        }
        Settings {
            SettingsView(updater: model.updater)
        }
    }
}
