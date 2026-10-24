import AppRoot
import Platform
import PlatformLive
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

/// UI tests launch with UI_TESTING=1: mocks only, no network or system side effects.
/// An environment variable, not an argument: AppKit reads `-key value` arguments as
/// defaults and opens a leftover argument as a file, and then no window appears.
private func makeUpdater() -> any UpdaterService {
    if ProcessInfo.processInfo.environment["UI_TESTING"] == "1" {
        return MockUpdaterService()
    }
    return LiveUpdaterService()
}
