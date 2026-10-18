import AppCore
import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel(greeter: LocalGreeter())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        Settings {
            SettingsView()
        }
    }
}
