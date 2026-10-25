# Recipes

Capabilities the template leaves out until an app needs them. Each keeps the rules in
[AGENTS.md](../AGENTS.md): services behind protocols, strings in the catalog, errors
logged once and shown by the view.

## Launch at login

`SMAppService` (macOS 13+) registers the app itself; no helper app, no entitlement. It
changes system state, so it is a service. The user can switch the item off in System
Settings > General > Login Items; the status then reads `requiresApproval`, and only
System Settings can switch it back on. The protocol, its status and its mock go in
`Platform/Core/LaunchAtLogin/`:

```swift
public enum LaunchAtLoginError: Error {
    case failed(any Error)
}

public enum LaunchAtLoginStatus: Sendable {
    case enabled
    case disabled
    /// Registered, but the user turned it off in System Settings, and only System
    /// Settings can turn it back on.
    case requiresApproval
}

@MainActor
public protocol LaunchAtLoginService: AnyObject {
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError)
    func openLoginItemsSettings()
}

@MainActor
public final class MockLaunchAtLoginService: LaunchAtLoginService {
    public var status: LaunchAtLoginStatus
    /// Thrown by `setEnabled(_:)`, for tests of a change that fails.
    public var failure: LaunchAtLoginError?

    public init(status: LaunchAtLoginStatus = .disabled, failure: LaunchAtLoginError? = nil) {
        self.status = status
        self.failure = failure
    }

    public func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError) {
        if let failure { throw failure }
        status = enabled ? .enabled : .disabled
    }

    public func openLoginItemsSettings() {}
}
```

The live one goes in `Platform/Live/LaunchAtLogin/`:

```swift
import Platform
import ServiceManagement

@MainActor
public final class LiveLaunchAtLoginService: LaunchAtLoginService {
    public init() {}

    // Users can change the item in System Settings, so the status is the only truth.
    public var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .disabled
        @unknown default: .disabled
        }
    }

    public func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            throw .failed(error)
        }
    }

    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
```

The switch goes in a General pane in `Features/Settings`: a `GeneralSettingsView` tab
before Updates in `SettingsView`. Its model catches and logs a failed change, so the
feature gets a `Log.swift`, as every module that logs has:

```swift
import Foundation
import OSLog

nonisolated enum Log {
    // Unbundled runs (`swift test`) have no bundle identifier.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "unbundled"

    static let settings = Logger(subsystem: subsystem, category: "settings")
}
```

The model holds the status and whether the last change failed. The user can change the
item in System Settings, so it reads the status again when asked:

```swift
import OSLog
import Observation
import Platform

@Observable
public final class LaunchAtLoginModel {
    public private(set) var status = LaunchAtLoginStatus.disabled
    public private(set) var failed = false
    private let service: any LaunchAtLoginService

    public init(service: any LaunchAtLoginService) {
        self.service = service
    }

    public func refresh() {
        status = service.status
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            try service.setEnabled(enabled)
            failed = false
        } catch {
            Log.settings.error("launch at login: \(String(describing: error))")
            failed = true
        }
        status = service.status
    }

    public func openLoginItemsSettings() {
        service.openLoginItemsSettings()
    }
}
```

When System Settings turned the item off, the toggle says so and offers the way there;
when the change fails, it says that too:

```swift
import AppKit
import Platform
import SwiftUI

struct LaunchAtLoginToggle: View {
    let model: LaunchAtLoginModel

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: Binding(get: { model.status == .enabled }, set: { model.setEnabled($0) })) {
                Text("Launch at login", bundle: .module)
            }
            .disabled(model.status == .requiresApproval)
            if model.status == .requiresApproval {
                Text("Turned off in System Settings.", bundle: .module)
                    .foregroundStyle(.secondary)
                Button {
                    model.openLoginItemsSettings()
                } label: {
                    Text("Open Login Items…", bundle: .module)
                }
            }
            if model.failed {
                Text("The login item could not be changed.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { model.refresh() }
        // Back from System Settings, the Settings window is still open.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
    }
}

#Preview {
    LaunchAtLoginToggle(model: LaunchAtLoginModel(service: MockLaunchAtLoginService(status: .requiresApproval)))
        .padding()
}
```

Keep the binding's `set:` a closure: passing the method `setEnabled` itself crashes the
Swift 6.2.3 compiler. Add `Launch at login`, `Turned off in System Settings.`,
`Open Login Items…` and `The login item could not be changed.` to
`Features/Settings/Resources/Localizable.xcstrings` in `en` and `zh-Hans`.
`App/Application/MainApp.swift` builds `LiveLaunchAtLoginService()` (the mock under
`UI_TESTING=1`) and passes it to `AppModel`, which owns a
`LaunchAtLoginModel(service:)`; `AppScenes` hands that to `SettingsView`. Test the model
in `Tests/Features/SettingsTests/` with the mock:

```swift
import Platform
import SettingsFeature
import Testing

@MainActor
struct LaunchAtLoginModelTests {
    struct Refused: Error {}

    @Test func failedChangeShowsAMessageAndKeepsTheStatus() {
        let model = LaunchAtLoginModel(service: MockLaunchAtLoginService(failure: .failed(Refused())))
        model.setEnabled(true)
        #expect(model.failed)
        #expect(model.status == .disabled)
    }
}
```

Check the item itself with the installed app in `/Applications` rather than a debug
build.

## Networking

`URLSession` with async/await and `Codable`; no networking library. The sandbox already
grants `com.apple.security.network.client` (Sparkle needs it). The protocol, the types
it returns, its error and its mock go in the Core of the domain that uses them; release
notes are about the app itself, so `Platform/Core/ReleaseNotes/`:

```swift
public struct ReleaseNotes: Decodable, Sendable {
    public let title: String

    public init(title: String) { self.title = title }
}

public enum ReleaseNotesError: Error {
    case requestFailed(any Error)
    case badStatus(Int)
    case decodingFailed(any Error)
}

public protocol ReleaseNotesService: Sendable {
    func latest() async throws(ReleaseNotesError) -> ReleaseNotes
}

public struct MockReleaseNotesService: ReleaseNotesService {
    public var notes: ReleaseNotes

    public init(notes: ReleaseNotes = ReleaseNotes(title: "Preview")) { self.notes = notes }

    public func latest() async throws(ReleaseNotesError) -> ReleaseNotes { notes }
}
```

The request goes in `Platform/Live/ReleaseNotes/`:

```swift
import Foundation
import Platform

public struct LiveReleaseNotesService: ReleaseNotesService {
    let url: URL
    let session: URLSession

    public init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    @concurrent
    public func latest() async throws(ReleaseNotesError) -> ReleaseNotes {
        let result: (Data, URLResponse)
        do {
            result = try await session.data(from: url)
        } catch {
            throw .requestFailed(error)
        }
        let (data, response) = result
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw .badStatus(status) }
        do {
            return try JSONDecoder().decode(ReleaseNotes.self, from: data)
        } catch {
            throw .decodingFailed(error)
        }
    }
}
```

`Platform` and `PlatformLive` are not MainActor by default, so `ReleaseNotes` decodes
off the main actor as it is. A `nonisolated async` function still runs on its caller's
actor; `@concurrent` moves the request and the decoding off the main actor a model
calls from. Tests and previews pass `MockReleaseNotesService`; they never hit the
network. What the live service decides itself, a bad status or a body that does not
decode, is tested in `PlatformTests` with a session whose configuration's
`protocolClasses` holds a `URLProtocol` that answers with canned responses.

## Menu bar app

### Menu beside a window

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

Add `About %@`, `Settings…` and `Quit` to `AppRoot/Resources/Localizable.xcstrings` in
`en` and `zh-Hans`, creating it and `resources: [.process("Resources")]` on the
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

### Menu-bar-only app

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

## Global keyboard shortcuts

A shortcut that works while another app is frontmost needs a system hotkey, a recorder
where the user picks it, and a check against shortcuts the system or the app's menus
already use. [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) does
all three and stores the choice in `UserDefaults`; it works in the sandbox and on the
Mac App Store without a permission prompt. It owns the hotkey, the storage and the
recorder, and no model logic sits between them, so there is no service to write (the
exception in AGENTS.md's service rule). Add it to `Package.swift`,
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
[Launch at login](#launch-at-login)):

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

Replace the activation (the menu bar recipe says why it ignores other apps) with the
app's action. An action that changes state is a model method, tested on its own; the
shortcut needs no mock. Listen with `events(_:for:)`, not `onKeyUp(for:)`: the package
plans to deprecate `onKeyUp`, and with warnings as errors that deprecation would break
the build. On macOS 15.0 and 15.1 a sandboxed app cannot register a shortcut whose only
modifiers are Option or Option-Shift; 15.2 lifted that. Add `Show app` to
`Features/Settings/Resources/Localizable.xcstrings` in `en` and `zh-Hans`.

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
features depend on (`make lint` rejects them in a feature). It is a kit: it knows
nothing of the app. Create it the first time: `Sources/Kits/AppKitBridge/`, and in
`Package.swift`
`.target(name: "AppKitBridge", path: "Sources/Kits/AppKitBridge", swiftSettings: ui)`.

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

// <Name>View(model: model).background(WindowReader { $0.level = .floating })
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
  `Package.swift` with an `exact:` version as a dependency of
  `PlatformLive` (create it beside `Platform/Core` if the app has none), start it from a
  function there that
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
  ask the user to allow access again
  ([RELEASING.md, 4a](RELEASING.md#4a-without-a-developer-id-default)).
- Structured data: SwiftData. `App/Application/MainApp.swift` builds the `ModelContainer` (an
  in-memory one under `UI_TESTING=1`) and hands it to `AppScenes`, which sets
  `.modelContainer(...)` on the scene. The store lives in the sandbox container under Application Support.
- Plain files: `URL.applicationSupportDirectory`, which resolves inside
  `~/Library/Containers/<bundle id>/Data/` under the sandbox.

## Privacy manifest

`App/Application/PrivacyInfo.xcprivacy` ships in every build and declares UserDefaults
(`CA92.1`: the app reads its own defaults). Add an entry when code or an SDK uses
another required-reason API (file timestamps, disk space, system boot time, active
keyboards) or collects data. The App Store checks it; Developer ID builds carry it
for consistency.
