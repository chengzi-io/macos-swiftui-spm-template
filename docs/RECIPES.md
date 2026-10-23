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

Step 2 reads the window from a view placed in it:

```swift
/// Hands the window that hosts this view to `configure` once the view is in it.
struct WindowReader: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> ReaderView { ReaderView(configure: configure) }
    func updateNSView(_ nsView: ReaderView, context: Context) {}

    final class ReaderView: NSView {
        let configure: (NSWindow) -> Void

        init(configure: @escaping (NSWindow) -> Void) {
            self.configure = configure
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { configure(window) }
        }
    }
}

// ContentView().background(WindowReader { $0.level = .floating })
```

Step 3 is an `NSWindowController` in `Sources/AppCore`, with each column an
`NSHostingController`. Here the split view belongs to the app, so its sidebar stays
fixed:

```swift
final class SidebarWindowController: NSWindowController {
    init(model: AppModel) {
        let sidebar = NSSplitViewItem(
            sidebarWithViewController: NSHostingController(rootView: Sidebar().environment(model))
        )
        sidebar.canCollapse = false
        sidebar.minimumThickness = 215
        sidebar.maximumThickness = 215
        let split = NSSplitViewController()
        split.addSplitViewItem(sidebar)
        let detail = NSHostingController(rootView: Detail().environment(model))
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

- The environment does not cross into an `NSHostingController`, so set
  `.environment(model)` on each root view.
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
