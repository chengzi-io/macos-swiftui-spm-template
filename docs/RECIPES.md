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

Replace (or add next to) the `WindowGroup` in `Sources/App/MainApp.swift`:

```swift
MenuBarExtra {
    ContentView().environment(model)
} label: {
    Image(systemName: "circle.hexagongrid")
}
.menuBarExtraStyle(.window)
```

For a menu-bar-only app with no Dock icon, add `LSUIElement` = `true` to
`Bundle/Info.plist`. Keep the `Settings` scene; open it with `SettingsLink`.

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
