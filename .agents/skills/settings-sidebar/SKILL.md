---
name: settings-sidebar
description: Turn the tabbed Settings window into one like System Settings - a sidebar of panes that cannot collapse, a search field, back and forward buttons, grouped forms - in an AppKit window that SwiftUI fills.
disable-model-invocation: true
---

# Settings with a sidebar

The template's Settings window is the `Settings` scene with one toolbar tab per pane, as
in Safari or TextEdit. That suits a few panes. With many, a sidebar reads better, as in
System Settings: the panes in a list, a search field that finds a pane by any of its
settings, back and forward, and each pane a grouped form.

SwiftUI cannot build that window. The `Settings` scene keeps the preferences toolbar,
and a `NavigationSplitView` sidebar collapses when its divider is dragged in, after
which nothing brings it back. So the window is AppKit's: an `NSWindowController` around
an `NSSplitViewController` whose sidebar has a fixed width, and both columns are
SwiftUI views in `NSHostingController`s. This is the third case of
[AppKit bridges](../add-capability/references/appkit-bridges.md), which lists what
owning a window costs.

Two choices follow System Settings rather than the HIG, on purpose. The HIG asks a
settings window to take the size of the current pane and suggests letting people hide
a sidebar; this window keeps System Settings' 715 × 600 points, and its sidebar cannot
collapse, because a sidebar of panes is how people move around it. Like the HIG asks,
it reopens on the pane last used, and its title follows the pane.

## What this skill expects from the project

It is written for apps made from macos-swiftui-spm-template:

- `Sources/Features/Settings/SettingsView.swift` is a `TabView` with one tab per pane
  view (the template's is `UpdatesSettingsView`), and its initializer takes the services
  the panes need.
- `Sources/AppRoot/AppScenes.swift` shows it in a `Settings` scene, and
  `Sources/AppRoot/AppModel.swift` holds those services.
- Package resources use `bundle: .module`, and each target with strings has a
  `Resources/Localizable.xcstrings` in `en` and `zh-Hans`.

`<skill>` below is this skill's directory, for example `.agents/skills/settings-sidebar`.

## What changes

| File | Change |
| --- | --- |
| `Sources/Kits/AppKitBridge/SearchField.swift` | New: `NSSearchField`, which takes ⌘F from anywhere in its window. Creates the `AppKitBridge` target if the project has none |
| `Sources/Features/Settings/SettingsWindowController.swift` | New: the window, the split view, the toolbar's back and forward buttons, and `SettingsCommand` (Settings…, ⌘,) |
| `SettingsPane.swift`, `SettingsNavigation.swift` | New: the panes with their titles, symbols and search keywords; the selected pane and its history |
| `SettingsSidebar.swift`, `SettingsDetail.swift` | New: the two columns |
| `SettingsView.swift` | Deleted: `SettingsDetail` shows the selected pane in its place |
| Each pane view | Grouped form; the window sizes it |
| `AppModel`, `AppScenes` | `showSettings(_:)` opens the window; the `Settings` scene goes |
| Tests | `SettingsPaneTests`, `SettingsNavigationTests`; the panes' renders change |

## 1. Add the files

```bash
mkdir -p Sources/Kits/AppKitBridge
cp <skill>/templates/AppKitBridge/SearchField.swift Sources/Kits/AppKitBridge/
cp <skill>/templates/Settings/*.swift Sources/Features/Settings/
cp <skill>/templates/Tests/*.swift Tests/Features/SettingsTests/
git rm Sources/Features/Settings/SettingsView.swift
```

Skip the first two lines if `Sources/Kits/AppKitBridge/` already has a search field, and
call that field in `SettingsSidebar` the way its initializer reads. In `Package.swift`,
add the target if it is new, beside the other library targets, and make `SettingsFeature`
depend on it:

```swift
        .target(
            name: "AppKitBridge",
            path: "Sources/Kits/AppKitBridge",
            swiftSettings: ui
        ),
```

```swift
            name: "SettingsFeature",
            dependencies: ["AppKitBridge", "Platform"],
```

## 2. One case per pane

The templates list the template's one pane, Updates. Make them match the tabs of the
`SettingsView` you deleted, in the same order, and add a case to each of the three for
every pane the app has:

- `SettingsPane`: a case per tab. Its title is the tab's text and its symbol an SF Symbol.
  `keywords` holds the label of every setting in the pane, as the same catalog keys the
  pane uses, so a search for "version" finds Updates.
- `SettingsDetail`: a `case` in the `switch` that builds the pane's view.
- The window opens on the pane last used; the first time, on the first case, so put
  the pane people open most first.
- If a pane takes more services than the updater, add them to `SettingsDetail`'s
  properties and to `SettingsWindowController.init`, as the deleted `SettingsView` did.

## 3. Each pane becomes a grouped form

System Settings' panes are grouped forms with the labels on the left and the controls on
the right. In each pane view:

- `.formStyle(.grouped)` on the `Form`, with its rows in `Section`s.
- Remove `.padding(…)`, `.frame(width: …)` and a picker's `.fixedSize()`: the window
  gives the pane its size, and grouped rows put each control at the trailing edge.
- Labels lose their trailing colon (`"Version:"` becomes `"Version"`): rename the key
  in the catalog and drop the colon from its zh-Hans value too (版本： becomes 版本).
- A note under a control becomes a second `Text` in its label, shown as a subtitle. A
  value with a button beside it is a `LabeledContent`. A control in a view of its own
  keeps the rows it adds (its note and its button).
- Give each pane's `#Preview` `.frame(width: 500, height: 400)`, the pane's room in the
  window.

The template's Updates pane comes out like this:

```swift
Form {
    Section {
        LabeledContent {
            CheckForUpdatesButton(updater: updater)
        } label: {
            Text("Version", bundle: .module)
            Text(version)
                .textSelection(.enabled)
        }
        Toggle(isOn: …) {
            Text("Automatically check for updates", bundle: .module)
        }
    }
}
.formStyle(.grouped)
```

## 4. Open the window

`AppModel` builds the window the first time it opens, and keeps it:

```swift
import SettingsFeature
```

```swift
    @ObservationIgnored private var settingsWindow: SettingsWindowController?
```

```swift
    /// Opens the Settings window, built the first time, on `pane` when one is given.
    public func showSettings(_ pane: SettingsPane? = nil) {
        let window =
            settingsWindow
            ?? SettingsWindowController(updater: updater)
        settingsWindow = window
        window.show(pane)
    }
```

In `AppScenes`, delete the `Settings { … }` scene, add the menu item to `.commands`, and
start the struct's comment with "Every window and menu command; `AppModel.showSettings`
opens Settings." in place of the words about the `Settings` scene:

```swift
            CommandGroup(replacing: .appSettings) {
                SettingsCommand { model.showSettings() }
            }
```

`openSettings`, `SettingsLink` and the `Settings` scene no longer reach Settings. Search
`Sources/` for them and call `model.showSettings()` instead, with a pane to open that
one (`model.showSettings(.updates)`). From a menu bar extra, call
`NSApp.activate(ignoringOtherApps: true)` first, or the window opens behind the
frontmost app. A view that cannot see `AppModel`, such as the menu bar recipe's
`MenuBarMenu`, takes an `openSettings: () -> Void` closure that `AppScenes` fills with
`{ model.showSettings() }`.

## 5. Strings

In `Sources/Features/Settings/Resources/Localizable.xcstrings`, add the keys `Back`,
`Forward` and `Settings…` with the zh-Hans values 返回, 前进 and 设置…. The key is the
English text, so English needs no entry of its own. Rename the keys whose colon went in
step 3. The window's title is the pane's title, which the catalog already
has.

## 6. Tests

`SettingsPaneTests` and `SettingsNavigationTests` test the template's panes; change the
queries and the panes they expect to the app's. `swift test` does not compile the string
catalog, so they match the English keys.

The window and its sidebar get no render: off screen the sidebar's `List` draws no rows
and its text no vibrancy. The panes keep theirs, and a grouped form has no height of its
own, so give each pane in `SettingsViewRenderTests` the pane's width in the window (715
minus the 215-point sidebar: 500) and a height, and say why in the suite's comment. A
pane whose form grows, such as one whose note appears only when a control is off, gets
a height of its own:

```swift
UpdatesSettingsView(updater: MockUpdaterService(), version: "1.2.0 (345)")
    .frame(width: 500, height: 140)
```

For the height, run `make test`, open the image it drew, and take the smallest height
that leaves about 20 points below the last section. The template's Updates pane needs
about 140.

Every pane's render changes. `make test` draws each one into `.build/renders/`: open the
images it wrote, show the user what changed, and keep them only once they agree.

## 7. Docs

In `AGENTS.md`:

- The rule on settings says where a setting's control goes. Make it say: a pane of the
  Settings window, which is a case of `SettingsPane`, with the control's label added to
  that pane's `keywords` so search finds it.
- Where it describes `AppRoot`, `AppScenes` holds windows and commands, and
  `AppModel.showSettings` opens Settings; there is no Settings scene.
- Where it and `docs/DEVELOPMENT.md` describe the layout, add `Kits/AppKitBridge/` if it
  is new.

In [the menu bar recipe](../add-capability/references/menu-bar.md), Settings opens through
`openSettings` and the recipe says to keep the `Settings` scene: make it pass the
`openSettings` closure from step 4 instead.

## 8. Check

`make fmt`, then `make ci`. Then `make run`, press ⌘, and check, in light and dark and
with `make run ARGS="-AppleLanguages '(zh-Hans)'"`:

- The window opens at 715 × 600 points. The sidebar's divider does not move, and the
  sidebar does not collapse.
- The list has focus; ⌘F moves to the search field. Typing a setting's label, such as
  "version", leaves only its pane; an empty field shows every pane.
- Back and forward move through the panes opened, and are dimmed at either end.
- The window's title is the pane's title.
- On macOS 15 and later, the line under the toolbar shows only while the pane is
  scrolled.
- After quitting and opening Settings again, the window is where it was, on the pane
  last used.

The branches for macOS 26 (rows that fade under the toolbar, the window's background
behind the form) compile against the SDK. If the user is not on macOS 26, say they have
not been seen there.

Commit it as one change, for example `feat(settings): show settings in a sidebar
window`. Reverting that commit brings back the tabs.
