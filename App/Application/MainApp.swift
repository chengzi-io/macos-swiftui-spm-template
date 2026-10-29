import AppRoot
import Notes
import NotesLive
import Platform
import PlatformLive
import SwiftUI

/// Composition root: the only place that knows the live services.
@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = makeModel()

    var body: some Scene {
        AppScenes(model: model)
    }
}

/// UI tests launch with UI_TESTING=1: mocks only, no network or system side effects.
/// An environment variable, not an argument: AppKit reads `-key value` arguments as
/// defaults and opens a leftover argument as a file, and then no window appears.
/// Debug builds only: in a shipped app, an environment variable must not swap a live
/// service (a license check, say) for its mock.
private func makeModel() -> AppModel {
    #if DEBUG
        if ProcessInfo.processInfo.environment["UI_TESTING"] == "1" {
            return AppModel(noteService: MockNoteService(), updater: MockUpdaterService())
        }
    #endif
    return AppModel(noteService: LiveNoteService(), updater: LiveUpdaterService())
}
