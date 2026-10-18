import AppCore
import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel(greeter: LocalGreeter())
    #if !APP_STORE
        @StateObject private var updates = Updates()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        #if !APP_STORE
            .commands {
                CommandGroup(after: .appInfo) {
                    CheckForUpdatesView(updates: updates)
                }
            }
        #endif
        Settings {
            #if APP_STORE
                SettingsView(automaticallyChecksForUpdates: nil)
            #else
                SettingsView(automaticallyChecksForUpdates: $updates.automaticallyChecksForUpdates)
            #endif
        }
    }
}
