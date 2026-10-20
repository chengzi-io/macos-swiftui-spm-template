# Recipes

Capabilities the template leaves out until an app needs them. Each keeps the rules in
[AGENTS.md](../AGENTS.md): services behind protocols, strings in the catalog, errors
logged once and shown by the view.

## Launch at login

`SMAppService` (macOS 13+) registers the app itself; no helper app, no entitlement.

```swift
import ServiceManagement
import SwiftUI

struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle(isOn: $enabled) {
            Text("Launch at login", bundle: .module)
        }
        .onChange(of: enabled) { _, newValue in
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.app.error("launch at login: \(error.localizedDescription, privacy: .public)")
                enabled = SMAppService.mainApp.status == .enabled
            }
        }
    }
}
```

`SMAppService.mainApp.status` is the source of truth: users can turn the item off in
System Settings → General → Login Items, so never store a separate flag. Registration
only works from the installed `.app`, not from the bare executable Xcode runs.

## Networking

`URLSession` with async/await and `Codable`; no networking library. The sandbox already
grants `com.apple.security.network.client` (Sparkle needs it).

```swift
// nonisolated: under the package's MainActor default, the Decodable conformance would
// otherwise be MainActor-isolated and unusable off the main actor.
nonisolated public struct ReleaseNotes: Decodable, Sendable {
    public let title: String
}

public protocol ReleaseNotesService {
    func latest() async throws -> ReleaseNotes
}

public enum ReleaseNotesError: Error {
    case badStatus(Int)
}

public struct LiveReleaseNotesService: ReleaseNotesService {
    let url: URL

    public init(url: URL) { self.url = url }

    @concurrent
    public func latest() async throws -> ReleaseNotes {
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw ReleaseNotesError.badStatus(status) }
        return try JSONDecoder().decode(ReleaseNotes.self, from: data)
    }
}
```

`@concurrent` moves the work off the main actor that the package uses by default; the
decoded type must be `nonisolated` and `Sendable`. Tests pass a stub
`ReleaseNotesService`; they do not hit the network.

## Menu bar app

### Menu beside a window

A `MenuBarExtra` in its default `.menu` style is a native menu, and each `Divider()` is
a separator between groups. The titles need `bundle: .module`, so the menu lives in
`Sources/AppCore/MenuBar/MenuBarMenu.swift`:

```swift
import AppKit
import SwiftUI

/// Content of a `MenuBarExtra` in its default `.menu` style; each `Divider()` becomes a
/// separator. `checkForUpdates` comes from `Sources/App`, where Sparkle lives.
public struct MenuBarMenu<CheckForUpdates: View>: View {
    @Environment(\.openSettings) private var openSettings
    private let checkForUpdates: CheckForUpdates
    private let appName =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "unbundled"

    public init(@ViewBuilder checkForUpdates: () -> CheckForUpdates) {
        self.checkForUpdates = checkForUpdates()
    }

    public var body: some View {
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
        checkForUpdates
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

Add it next to the `WindowGroup` in `Sources/App/MainApp.swift`; `CheckForUpdatesView`
comes in from there because Sparkle lives in `Sources/App`:

```swift
MenuBarExtra {
    MenuBarMenu { CheckForUpdatesView(updates: updates) }
} label: {
    Image(systemName: "circle.hexagongrid")
}
```

Add `About %@`, `Settings…` and `Quit` to `Localizable.xcstrings` in `en` and
`zh-Hans`. Settings uses `openSettings` rather than `SettingsLink`, which cannot
activate the app. Apple plans to deprecate `activate(ignoringOtherApps:)` (its
documentation lists macOS 27), but Swift warns only once the deployment target reaches
that release; `activate()` alone still leaves windows in the Stage Manager strip now
and then.

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
window: replace `WindowGroup {` with `Window(appName, id: "main") {`, where `appName`
is `CFBundleDisplayName` read from `Bundle.main` as `MenuBarMenu` does. An app that
shows several windows at once (documents, one per item) keeps
`WindowGroup(id: "main")`, where each click opening a new window is the point.

### Menu-bar-only app

Replace the `WindowGroup` in `Sources/App/MainApp.swift` with a panel that holds the
app's view:

```swift
MenuBarExtra {
    ContentView().environment(model)
} label: {
    Image(systemName: "circle.hexagongrid")
}
.menuBarExtraStyle(.window)
```

For no Dock icon, add `LSUIElement` = `true` to `Bundle/Info.plist`. That also hides
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

## Crash reporting

Developer ID apps get no crash reports from Apple; they stay in
`~/Library/Logs/DiagnosticReports` on the user's Mac. Pick one when the app has users:

- **Sentry**: add `https://github.com/getsentry/sentry-cocoa` to `Package.swift` with an
  `exact:` version, start it in `AppDelegate.applicationDidFinishLaunching`, and upload
  `dist/*.dSYM.zip` with `sentry-cli debug-files upload` in the publish job. Declare
  the collected data in the privacy manifest.
- **MetricKit**: subscribe with `MXMetricManager.shared.add(_:)`; crash and hang
  diagnostics (`MXDiagnosticPayload`) arrive on the next launch. You send them to your
  own endpoint and symbolicate with the release dSYM.

Either way, ask for consent where your privacy policy requires it.

## Keychain and structured data

- Tokens and passwords: Keychain through `SecItemAdd` / `SecItemCopyMatching` in a
  small service. Ad-hoc builds change signature on every update, so the keychain may
  ask the user to allow access again (see docs/RELEASING.md, 4a).
- Structured data: SwiftData (`ModelContainer` in `MainApp`, `.modelContainer(...)` on
  the scene). The store lives in the sandbox container under Application Support.
- Plain files: `URL.applicationSupportDirectory`, which resolves inside
  `~/Library/Containers/<bundle id>/Data/` under the sandbox.

## Privacy manifest

`Bundle/PrivacyInfo.xcprivacy` ships in every build and declares UserDefaults
(`CA92.1`: the app reads its own defaults). Add an entry when code or an SDK uses
another required-reason API (file timestamps, disk space, system boot time, active
keyboards) or collects data. The App Store checks it; Developer ID builds carry it
for consistency.
