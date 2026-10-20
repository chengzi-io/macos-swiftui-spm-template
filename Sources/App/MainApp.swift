import AppCore
import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()
    @StateObject private var updates = Updates()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updates: updates)
            }
        }
        Settings {
            SettingsView(automaticallyChecksForUpdates: $updates.automaticallyChecksForUpdates)
        }
    }
}
