# Launch at login

`SMAppService` (macOS 13+) registers the app itself; no helper app, no entitlement. It
changes system state, so it is a service. The user can switch the item off in System
Settings > General > Login Items; the status then reads `requiresApproval`, and only
System Settings can switch it back on. The protocol, its status and its mock go in
`Domains/Platform/LaunchAtLogin/`:

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

The live one goes in `Domains/PlatformLive/LaunchAtLogin/`:

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
`Features/Settings/Resources/Localizable.xcstrings` in every locale of `REQUIRED_LOCALES`.
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
