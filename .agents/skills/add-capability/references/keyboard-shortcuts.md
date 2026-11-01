# Global keyboard shortcuts

A shortcut that works while another app is frontmost needs a system hotkey, a recorder
where the user picks it, and a check against shortcuts the system or the app's menus
already use. [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) does
all three and stores the choice in `UserDefaults`; it works in the sandbox and on the
Mac App Store without a permission prompt. It owns the hotkey, the storage and the
recorder, and no model logic sits between them, so there is no service to write (the
exception in the service rule of `Sources/AGENTS.md`). Add it to `Package.swift`,
and its product to the dependencies of `SettingsFeature` and `AppRoot`:

```swift
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "3.1.0"),
```

```swift
.product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
```

The Settings feature names the shortcut in `Features/Settings/Shortcuts.swift`:

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // No initial shortcut: one the app picks can take over a shortcut the user relies on.
    public static let showApp = Self("showApp")
}
```

and shows its recorder in the General pane's `Form` (`GeneralSettingsView`, as in
[launch at login](launch-at-login.md)):

```swift
KeyboardShortcuts.Recorder(for: .showApp) {
    Text("Show app", bundle: .module)
}
```

`AppModel` listens in its `init`, with `import AppKit`, `import KeyboardShortcuts` and
`import SettingsFeature`; `AppRoot` already depends on every feature and owns the models
an action changes:

```swift
// Runs as long as the app does; inactive until the user records a shortcut.
Task {
    for await _ in KeyboardShortcuts.events(.keyUp, for: .showApp) {
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

Replace the activation ([menu-bar.md](menu-bar.md) says why it ignores other apps) with the
app's action. An action that changes state is a model method, tested on its own; the
shortcut needs no mock. Listen with `events(_:for:)`, not `onKeyUp(for:)`: the package
plans to deprecate `onKeyUp`, and with warnings as errors that deprecation would break
the build. On macOS 15.0 and 15.1 a sandboxed app cannot register a shortcut whose only
modifiers are Option or Option-Shift; 15.2 lifted that. Add `Show app` to
`Features/Settings/Resources/Localizable.xcstrings` in every locale of `REQUIRED_LOCALES`.
