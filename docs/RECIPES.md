# Recipes

Capabilities the template leaves out until an app needs them. Each keeps the rules in
[AGENTS.md](../AGENTS.md): services behind protocols, strings in the catalog, errors
logged once and shown by the view.

## Launch at login

`SMAppService` (macOS 13+) registers the app itself; no helper app, no entitlement. It
changes system state, so it is a service. The protocol and its mock go in `Services`:

```swift
@MainActor
public protocol LaunchAtLoginService: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
public final class MockLaunchAtLoginService: LaunchAtLoginService {
    public private(set) var isEnabled: Bool

    public init(isEnabled: Bool = false) { self.isEnabled = isEnabled }

    public func setEnabled(_ enabled: Bool) throws { isEnabled = enabled }
}
```

The live one goes in `ServicesLive`:

```swift
import ServiceManagement
import Services

@MainActor
public final class LiveLaunchAtLoginService: LaunchAtLoginService {
    public init() {}

    // Users can turn the item off in System Settings, so the status is the only truth.
    public var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

The toggle goes in `Features/Settings`, with a `Log.swift` like Greeting's that declares
a `settings` category:

```swift
import OSLog
import Services
import SwiftUI

struct LaunchAtLoginToggle: View {
    let service: any LaunchAtLoginService
    @State private var enabled = false

    var body: some View {
        Toggle(isOn: $enabled) {
            Text("Launch at login", bundle: .module)
        }
        .onAppear { enabled = service.isEnabled }
        .onChange(of: enabled) { _, newValue in
            guard newValue != service.isEnabled else { return }
            do {
                try service.setEnabled(newValue)
            } catch {
                Log.settings.error("launch at login: \(error.localizedDescription, privacy: .public)")
                enabled = service.isEnabled
            }
        }
    }
}
```

`App/MainApp.swift` builds `LiveLaunchAtLoginService()` (the mock under `UI_TESTING=1`)
and `AppModel` hands it to `SettingsView`. Check it with the installed app in
`/Applications` rather than a debug build.

## Networking

`URLSession` with async/await and `Codable`; no networking library. The sandbox already
grants `com.apple.security.network.client` (Sparkle needs it). The protocol, the types
it returns, its error and its mock go in `Services`:

```swift
public struct ReleaseNotes: Decodable, Sendable {
    public let title: String

    public init(title: String) { self.title = title }
}

public enum ReleaseNotesError: Error {
    case badStatus(Int)
}

public protocol ReleaseNotesService: Sendable {
    func latest() async throws -> ReleaseNotes
}

public struct MockReleaseNotesService: ReleaseNotesService {
    public var notes: ReleaseNotes

    public init(notes: ReleaseNotes = ReleaseNotes(title: "Preview")) { self.notes = notes }

    public func latest() async throws -> ReleaseNotes { notes }
}
```

The request goes in `ServicesLive`:

```swift
import Foundation
import Services

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

`Services` and `ServicesLive` are not MainActor by default, so `ReleaseNotes` decodes
off the main actor as it is. A `nonisolated async` function still runs on its caller's
actor; `@concurrent` moves the request and the decoding off the main actor a model
calls from. Tests and previews pass `MockReleaseNotesService`; they never hit the
network.

## Menu bar app

### Menu beside a window

A `MenuBarExtra` in its default `.menu` style is a native menu, and each `Divider()` is
a separator between groups. Menus belong to `AppRoot`, beside `CheckForUpdatesButton`:
`Packages/AppModules/Sources/AppRoot/MenuBarMenu.swift`.

```swift
import AppKit
import Services
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

Add `About %@`, `Settings…` and `Quit` to `AppRoot/Resources/Localizable.xcstrings` in
`en` and `zh-Hans`. Settings uses `openSettings` rather than `SettingsLink`, which cannot
activate the app. Apple plans to deprecate `activate(ignoringOtherApps:)` (its
documentation lists macOS 27), but Swift warns only once the deployment target reaches
that release; `activate()` alone still leaves windows in the Stage Manager strip now
and then. This was checked on macOS 15.7 with Stage Manager, not on macOS 26 or later.

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

### Menu-bar-only app

Replace the `WindowGroup` in `AppRoot/AppScenes.swift` with a panel that holds the
app's view:

```swift
MenuBarExtra {
    GreetingView(model: model.greeting)
} label: {
    Image(systemName: "circle.hexagongrid")
}
.menuBarExtraStyle(.window)
```

For no Dock icon, add `INFOPLIST_KEY_LSUIElement = YES` to `Configs/App.xcconfig`. That also hides
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

## AppKit bridges

SwiftUI comes first. When no public SwiftUI API does the job, including APIs behind
`#available` (the app targets macOS 14), bridge at the layer that is missing. Go down a
step only when the step above cannot do it:

1. **A view SwiftUI lacks**, such as rich text in `NSTextView` or an `NSTableView` with
   100,000 rows: wrap it in `NSViewRepresentable`, or in `NSViewControllerRepresentable`
   for a view controller. The scene stays SwiftUI. Delegates go on the coordinator, and
   `dismantleNSView` removes observers and timers.
2. **A window property you set once**: read the hosting `NSWindow` and set the property.
   This is also how macOS 14 gets a newer modifier, such as `windowLevel(_:)` or
   `windowMinimizeBehavior(_:)` (both macOS 15+). It holds only while SwiftUI leaves the
   property alone, so check it again after the window reopens.
3. **The window's structure**, such as a sidebar that cannot collapse, the toolbar's
   layout, the line under the toolbar, or an `NSPanel`: AppKit owns the window, and
   SwiftUI fills it.

Move to step 3 when SwiftUI keeps resetting what step 2 set, or when the workaround
starts to depend on timing, notifications or delays. Never swizzle, call private API or
poll to reapply a value.

Steps 1 and 2 are representables, and they live in an `AppKitBridge` target that
features depend on (`make lint` rejects them in a feature). Create it the first time:
`Packages/AppModules/Sources/AppKitBridge/`, and in `Package.swift`
`.target(name: "AppKitBridge", swiftSettings: ui)`.

Step 2 reads the window from a view placed in it:

```swift
import AppKit
import SwiftUI

/// Hands the window that hosts this view to `configure` once the view is in it.
public struct WindowReader: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    public init(configure: @escaping (NSWindow) -> Void) {
        self.configure = configure
    }

    public func makeNSView(context: Context) -> ReaderView { ReaderView(configure: configure) }
    public func updateNSView(_ nsView: ReaderView, context: Context) {}

    public final class ReaderView: NSView {
        let configure: (NSWindow) -> Void

        init(configure: @escaping (NSWindow) -> Void) {
            self.configure = configure
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override public func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { configure(window) }
        }
    }
}

// GreetingView(model: model).background(WindowReader { $0.level = .floating })
```

Step 3 is an `NSWindowController` in `AppRoot`, which owns the windows, with each column
an `NSHostingController`. Here the split view belongs to the app, so its sidebar stays
fixed:

```swift
final class SidebarWindowController: NSWindowController {
    init(model: AppModel) {
        let sidebar = NSSplitViewItem(
            sidebarWithViewController: NSHostingController(rootView: Sidebar(model: model))
        )
        sidebar.canCollapse = false
        sidebar.minimumThickness = 215
        sidebar.maximumThickness = 215
        let split = NSSplitViewController()
        split.addSplitViewItem(sidebar)
        let detail = NSHostingController(rootView: Detail(model: model))
        split.addSplitViewItem(NSSplitViewItem(viewController: detail))

        // Without .miniaturizable and .resizable, minimize and zoom are dimmed.
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.contentViewController = split
        window.setContentSize(NSSize(width: 715, height: 600))
        super.init(window: window)
        // On the controller: `init(window:)` clears a name set on the window.
        windowFrameAutosaveName = "Settings"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
```

Owning the window costs this:

- The scene's environment does not cross into an `NSHostingController`. Models already
  reach views through their initializers, so pass the model to each hosted root view.
- AppKit observes the same `@Observable` model with `withObservationTracking`. It fires
  once, so register again in `onChange`, on the main actor.
- Build the toolbar with `NSToolbar`. When SwiftUI's `.toolbar` built it from a hosted
  view, the window's first title came out unlocalized.
- `SettingsLink`, `openSettings` and `openWindow` cannot open the window. The app keeps
  the controller and shows it from its menu commands.
- AppKit and SwiftUI do not always stay in sync. For example, the automatic line under
  the toolbar stopped tracking the scroll position once SwiftUI replaced the pane's
  content, so check each macOS release.

Settings with a vertical sidebar is a step 3 case. The `Settings` scene keeps the
preferences toolbar, so the title stays centered. A `NavigationSplitView` sidebar
collapses when its divider is dragged in. UserDefaults saves the collapsed state
(`NSSplitView Subview Frames …`) and restores it on the next launch. Once the sidebar
toggle is removed, nothing brings the sidebar back. Either keep the toggle (a `Window`
scene with `NavigationSplitView`) or own the window as above. This was checked on
macOS 15.7.

## Crash reporting

Developer ID apps get no crash reports from Apple; they stay in
`~/Library/Logs/DiagnosticReports` on the user's Mac. Pick one when the app has users:

- **Sentry**: add `https://github.com/getsentry/sentry-cocoa` to
  `Packages/AppModules/Package.swift` with an `exact:` version as a dependency of
  `ServicesLive`, start it from a function there that
  `AppDelegate.applicationDidFinishLaunching` calls, and upload
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
- Structured data: SwiftData. `App/MainApp.swift` builds the `ModelContainer` (an
  in-memory one under `UI_TESTING=1`) and hands it to `AppScenes`, which sets
  `.modelContainer(...)` on the scene. The store lives in the sandbox container under Application Support.
- Plain files: `URL.applicationSupportDirectory`, which resolves inside
  `~/Library/Containers/<bundle id>/Data/` under the sandbox.

## Privacy manifest

`App/PrivacyInfo.xcprivacy` ships in every build and declares UserDefaults
(`CA92.1`: the app reads its own defaults). Add an entry when code or an SDK uses
another required-reason API (file timestamps, disk space, system boot time, active
keyboards) or collects data. The App Store checks it; Developer ID builds carry it
for consistency.
