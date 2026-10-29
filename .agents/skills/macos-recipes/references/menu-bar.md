# Menu bar app

## Menu beside a window

A `MenuBarExtra` in its default `.menu` style is a native menu, and each `Divider()` is
a separator between groups. Menus belong to `AppRoot`, beside `AppScenes`:
`Sources/AppRoot/MenuBarMenu.swift`.

```swift
import AppKit
import Platform
import SettingsFeature
import SwiftUI

/// Content of a `MenuBarExtra` in its default `.menu` style; each `Divider()` becomes a
/// separator.
struct MenuBarMenu: View {
    @Environment(\.openSettings) private var openSettings
    let updater: any UpdaterService
    private let appName =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "unbundled"

    var body: some View {
        // The app's own groups go here, each followed by a Divider().
        // A menu bar extra does not activate the app, and activate() is only a request
        // the system may decline: the window then opens behind the frontmost app or in
        // the Stage Manager strip. Activate first, ignoring other apps.
        Button {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        } label: {
            Text("About \(appName)", bundle: .module)
        }
        CheckForUpdatesButton(updater: updater)
        Button {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        } label: {
            Text("Settings…", bundle: .module)
        }
        .keyboardShortcut(",")
        Divider()
        Button {
            NSApp.terminate(nil)
        } label: {
            Text("Quit", bundle: .module)
        }
        .keyboardShortcut("q")
    }
}
```

Add it next to the `WindowGroup` in `AppRoot/AppScenes.swift`:

```swift
MenuBarExtra {
    MenuBarMenu(updater: model.updater)
} label: {
    Image(systemName: "circle.hexagongrid")
}
```

Add `About %@`, `Settings…` and `Quit` to `AppRoot/Resources/Localizable.xcstrings` in every locale of
`REQUIRED_LOCALES`, creating it and `resources: [.process("Resources")]` on the
`AppRoot` target if AppRoot has no strings yet. Settings uses `openSettings` rather than
`SettingsLink`, which cannot activate the app. Apple plans to deprecate
`activate(ignoringOtherApps:)` (its documentation lists macOS 27), but Swift warns only
once the deployment target reaches that release; `activate()` alone still leaves
windows in the Stage Manager strip now and then. This was checked on macOS 15.7 with
Stage Manager, not on macOS 26 or later.

An item that opens the main window is optional. Add it to `MenuBarMenu` as the first
group, its title in the catalog, when people come back to a window from the menu bar;
an app whose menu is the whole interface leaves it out:

```swift
@Environment(\.openWindow) private var openWindow

Button {
    NSApp.activate(ignoringOtherApps: true)
    openWindow(id: "main")
} label: {
    Text("Open Window", bundle: .module)
}
Divider()
```

The scene decides what the item does: `openWindow(id:)` brings a `Window` to the front,
but opens another window from a `WindowGroup` on every call. Most apps have one main
window: replace `WindowGroup {` in `AppScenes` with `Window(appName, id: "main") {`, where `appName`
is `CFBundleDisplayName` read from `Bundle.main` as `MenuBarMenu` does. An app that
shows several windows at once (documents, one per item) keeps
`WindowGroup(id: "main")`, where each click opening a new window is the point.

## Menu-bar-only app

Replace the `WindowGroup` in `AppRoot/AppScenes.swift` with a panel that holds the
app's view:

```swift
MenuBarExtra {
    <Name>View(model: model.<name>)
} label: {
    Image(systemName: "circle.hexagongrid")
}
.menuBarExtraStyle(.window)
```

For no Dock icon, add `INFOPLIST_KEY_LSUIElement = YES` to `App/Configs/App.xcconfig`. That also hides
the app menu, so the panel carries its own Settings and Quit. Keep the `Settings`
scene and open it as the menu above does; `SettingsLink` does not activate the app and
leaves the window behind the frontmost one:

```swift
@Environment(\.openSettings) private var openSettings

Button {
    NSApp.activate(ignoringOtherApps: true)
    openSettings()
} label: {
    Text("Settings…", bundle: .module)
}
Button {
    NSApp.terminate(nil)
} label: {
    Text("Quit", bundle: .module)
}
```
