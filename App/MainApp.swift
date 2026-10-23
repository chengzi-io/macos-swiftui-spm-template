import AppRoot
import Services
import ServicesLive
import SwiftUI

/// Composition root: the only place that knows the live services.
@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel(updater: makeUpdater())

    var body: some Scene {
        AppScenes(model: model)
    }
}

/// UI tests launch with --ui-testing: mocks only, no network or system side effects.
private func makeUpdater() -> any UpdaterService {
    if CommandLine.arguments.contains("--ui-testing") {
        return MockUpdaterService()
    }
    return LiveUpdaterService()
}
