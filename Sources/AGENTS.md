# Sources

Rules for the package's library targets: where code goes, what may depend on what, and
how it is written. Supplements the root [AGENTS.md](../AGENTS.md); why it is laid out
this way: [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).

## Layers

| Folder | Target | Holds |
|---|---|---|
| `AppRoot/` | `AppRoot` | `AppModel` (root of the model tree), `AppScenes` (windows, commands, Settings) |
| `Features/<Name>/` | `<Name>Feature` | one area the user works in: its screens, `<Name>Model`, logic only it uses, `Resources/Localizable.xcstrings` |
| `Platform/Core/<Name>/` | `Platform` | what any Mac app needs from the system: a protocol per outside thing, its types, its error enum, `Mock<Name>Service` |
| `Platform/Live/<Name>/` | `PlatformLive` | `Live<Name>Service`: system APIs, network, files, Sparkle |
| `<Domain>/Core/<Name>/` | `<Domain>` | what this app is about: protocols, value types, pure logic, shared models, mocks |
| `<Domain>/Live/<Name>/` | `<Domain>Live` | the domain's live services; none when nothing is outside the process |

- Create a folder the first time something needs it: a new domain (`Monitor`, `Sync`), `DesignSystem/` (tokens and shared components, no domain), `Kits/<Name>/` (code that knows nothing of this app).
- A feature is an area, not a screen: screens that share data and change together share a target, a folder each.
- A domain groups capabilities that change together, not one per service. Every new library target is declared in `Package.swift`; a domain's two targets join the `AppModules` product.
- Do not name a module after a SwiftUI type (`Settings`, `App`): it breaks `Settings.SomeType` lookups. Features end in `Feature`.

## Dependencies

| Target | May depend on |
|---|---|
| `AppRoot` | `<Name>Feature`, `<Domain>`, `Platform` |
| `<Name>Feature` | `<Domain>`, `Platform`, `DesignSystem`, `Kits` |
| `<Domain>` | another `<Domain>` (no cycles), `Platform`, `Kits` |
| `…Live` | its Core, other Cores, `Kits`; never another Live |
| `DesignSystem` | `Kits` |

- Only the app target (`App/Application/MainApp.swift`) knows the Live targets; `make lint` fails on any other target depending on one, or on a feature depending on a feature.
- `make test` fails on an import the target does not declare (`--explicit-target-dependency-import-check`).
- A flow that spans domains without a screen belongs to the domain that consumes the others' results, as a plain type; not to a Live, `MainApp` or a model.
- Sparkle is the one third-party package: pinned `exact` in `Package.swift`, used only by `PlatformLive`. Do not add another package without the user's yes.

## Concurrency and services

- Features, `AppRoot` and `RenderSupport` default to MainActor (`swiftSettings: ui`); `Platform`, domains and Lives do not (`common`). Keep it that way.
- Mark UI-bound services and a domain's models `@MainActor`, background work `@concurrent`; a plain `nonisolated async` function runs on its caller's actor.
- In MainActor targets `Bundle.module` is MainActor-isolated: resolve user-facing text in views or models; values decoded off the main actor need `nonisolated struct …: Codable, Sendable`.
- Anything outside the process (system API, network, files, UserDefaults, Keychain, the clock) is a service: protocol and mock in a Core, live implementation in the matching Live, passed in through an initializer. No DI container.
- Pure logic (formatting, parsing, state machines) is a plain type the model calls directly, with no protocol.
- No service for a package that owns the access, storage and control alike (KeyboardShortcuts), or for SwiftData: a view reads with `@Query`, the model writes through a `ModelContext`, tests use an in-memory store.
- Time: take `any Clock<Duration>` through the initializer; only a Live reads the system clock. Write a `ManualClock` for tests when the first feature needs one.
- Models are `@Observable` and reach views through initializers. A feature's `<Name>Model` owns its screens' models; `AppModel` owns the features' models and app-wide state.

## Write

- Every view has a `#Preview` built from mocks.
- Package resources need `bundle: .module` (`Text("Key", bundle: .module)`); without it the raw key shows and nothing fails to compile.
- Every user-facing string goes in its target's `Localizable.xcstrings`, translated into each locale of `REQUIRED_LOCALES` (`App/Configs/Identity.xcconfig`).
- Errors: each service throws its own `enum …Error: Error`; the model catches once, logs, and turns it into state the view shows. No empty `catch`, no `try?` on errors that matter.
- Logging: each module has an internal `Log` enum of `os.Logger`s (subsystem: the bundle id) with its own category; dynamic values stay private unless marked `privacy: .public`. Never log tokens or personal data.
- Warnings are errors. Fix them, do not silence them. `MemberImportVisibility` is on: import every module whose members a file uses.

## Forbidden (`make lint`, [scripts/lint-rules.sh](../scripts/lint-rules.sh))

| Do not | Do instead |
|---|---|
| `ObservableObject`, `@Published` | `@Observable` |
| `NavigationView` | `NavigationStack`, `NavigationSplitView` |
| `.foregroundColor(_:)` | `.foregroundStyle(_:)` |
| `import SwiftUI` in a Core or Live | views belong in a feature |
| `import AppKit`, `IOKit`, `Network`, `Sparkle` in a Core | system frameworks belong in a Live |
| `@unchecked Sendable`, `nonisolated(unsafe)` | an actor, a `Sendable` value, or `OSAllocatedUnfairLock` |
| `.environment(model)`, `@Environment(Model.self)` | pass the model through `init` |
| `static let shared` | pass the service through `init` |
| `Date()`, `Date.now` outside a Live | an injected `Clock` |
| `print`, `debugPrint` | the module's `Log` |
| `try!` | handle or throw the error |
