# AGENTS.md

macOS SwiftUI app. A thin Xcode project (`Pomelo.xcodeproj`) builds, signs and packages
the app; all code lives in the local Swift package `Packages/AppModules`; `scripts/`
ships it. Setup and the layout live in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md), the
commands in `make help`; this file is the rules of engagement.

<!-- template-only:start -->
## Before init

`scripts/init.sh` has not run, so this repository is still the template and `README.md`
describes the template. When the user asks for app work (a feature, an icon, a
release), first ask for the app name and bundle identifier, run
`scripts/init.sh --name <Name> --bundle-id <id>` on a clean tree, show the user the
`git diff` and commit it as `chore: initialize <Name> from template`. Then `make setup`;
`make snapshots`, which records the demo's view snapshots on this Mac (init removed the
template's): show the user the images and commit them after their yes; then `make ci`. The one-time release setup in [docs/RELEASING.md](docs/RELEASING.md)
needs the user's GitHub and Apple accounts, so it stays with them. When the user is
changing the template itself, leave init alone. Init removes this section.
<!-- template-only:end -->

## Gate commands

```bash
make test    # unit tests (swift test): seconds; run after every change
make ci      # definition of done: lint (format, scripts/lint-rules.sh, asset catalogs), unit tests, debug .app, launch smoke test
make run     # build and launch the debug app; logs go to the terminal (or .build/run.log)
make fmt     # format Swift sources (the pre-commit hook formats staged files too)
```

`make snapshots` records view snapshots; only after the user has seen the images (see
Rules).

`make test:ui` runs the XCUITests. They take over the user's mouse and keyboard, so run
them only when the user asks; GitHub CI runs them on every PR.

Toolchain: Xcode 26 (Swift 6.2); the app targets macOS 14+. `make doctor` checks it.
On macOS 26+ with Xcode 26.3+ and the project open in Xcode, `xcrun mcpbridge` lets an
agent build, run tests, render previews and search Apple's documentation through Xcode.
On macOS 15 it does not launch; the make targets do all of it but previews.

## Where things go

```text
Pomelo/                       @main, the composition root: builds the live services
                              (mocks under UI_TESTING=1) and hands them to AppRoot.
                              Plus the app delegate, assets, AppIcon.icon. No views.
PomeloUITests/                XCUITest, a few critical flows; launches with UI_TESTING=1
Configs/Identity.xcconfig     app identity (name, bundle id, team, repository): only here
Configs/*.xcconfig            build settings; Info.plist and App.entitlements beside them
Packages/AppModules/Sources/
  AppRoot/                    AppModel (root of the model tree), AppScenes (windows,
                              commands, Settings), app-wide menus
  Features/<Name>/            target <Name>Feature: <Name>View, <Name>Model, logic only
                              it uses, Resources/Localizable.xcstrings
  Services/                   a protocol for each thing outside the process, its types,
                              its error enum and a Mock<Name>Service
  ServicesLive/               Live<Name>Service: system APIs, network, files, Sparkle
Packages/AppModules/Tests/    Swift Testing, mirroring Sources/ (<Name>FeatureTests)
```

Create these targets the first time something needs them, not before: `Models/` for
value types and pure logic that several features share, `DesignSystem/` for shared
SwiftUI components, `AppKitBridge/` for `NSViewRepresentable` wrappers and NSWindow or
NSEvent helpers ([RECIPES](docs/RECIPES.md#appkit-bridges)).

Dependencies, enforced by `Package.swift`:

```text
Pomelo ──► AppRoot ──► <Name>Feature ──► Services (and Models, DesignSystem, AppKitBridge)
 └────► ServicesLive ──► Services
```

A feature never depends on `ServicesLive` or on another feature; only `Pomelo` knows the
live services. `README.md` is the app's page for its users; developer docs go in
`docs/`. Skills live in `.agents/skills/`, and `.claude/skills/` links to each one: link
a new skill the same way.

## Rules

- Something outside the process (system API, network, files, UserDefaults, Keychain,
  the clock) that a model needs is a service: protocol and mock in `Services`, live
  implementation in `ServicesLive`. Pure logic (formatting, parsing, calculation, state
  machines) stays a plain type the model calls directly, as `Greeter` is; it gets no
  protocol. For time, take `any Clock<Duration>`.
- Models are `@Observable` and reach views through initializers, never
  `.environment(...)`: a missing initializer argument fails the build, a missing
  environment object crashes at run time. `AppModel` owns the feature models.
- Every view has a `#Preview` built from mocks.
- Package resources need `bundle: .module`: `Text("Key", bundle: .module)`,
  `String(localized: "Key", bundle: .module)`, `Image("name", bundle: .module)`.
  Without it SwiftUI looks in the main bundle and shows the raw key; nothing fails at
  compile time. Each target with strings has its own `Localizable.xcstrings` (en,
  zh-Hans).
- Feature targets and AppRoot are MainActor by default; `Services` and `ServicesLive`
  are not. Mark UI-bound services `@MainActor`, and background work `@concurrent`: a
  plain `nonisolated async` function runs on its caller's actor.
- In MainActor-by-default targets `Bundle.module` is MainActor-isolated, so nonisolated
  code (Error types, Sendable values) cannot read it. Resolve user-facing text in views
  or models, as `GreeterError.message` does. Value types decoded or passed off the main
  actor there need `nonisolated struct …: Codable, Sendable`.
- Warnings are errors, in the package and in the app. Fix them; do not silence them.
  `MemberImportVisibility` is on: import every module whose members a file uses
  (`import OSLog` for `Logger` interpolation).
- Errors: each service throws its own `enum …Error: Error`; the model catches once,
  logs, and turns the error into state the view shows. No empty `catch`, no `try?` on
  errors that matter.
- Logging: each module has an internal `Log` enum of `os.Logger`s with its own category
  (`Log.greeting`); subsystem = bundle identifier. Dynamic values stay private unless
  marked `privacy: .public`; never log tokens or personal data. `make logs` streams
  them.
- Module names end in `Feature` (`SettingsFeature`), and no module is named after a
  SwiftUI type: a module called `Settings` or `App` breaks `Settings.SomeType` lookups.
- Tests: Swift Testing (`@Test`, `#expect`) on models and services, with mocks for
  every service. `swift test` does not compile asset or string catalogs, so unit tests
  never assert localized text or images; `make smoke` covers resources in the real
  `.app`. XCTest only for UI tests.
- Views get snapshot tests (swift-snapshot-testing; `GreetingViewSnapshotTests` is the
  pattern): rendered at 2x through `NSHostingView`, light and dark, in English. The PNGs
  in `__Snapshots__/` beside the test are how an agent sees a view without Xcode: read
  them. Tests never record: a missing or changed reference fails, and the failure names
  the reference and the new image.
- Recording a snapshot is the user's call. When one fails after a change you meant to
  make, or a new test has no reference, read the old and the new image, show the user
  what changed, and wait for their yes; then `make snapshots` (Claude Code asks too).
  Never record any other way (`SNAPSHOT_TESTING_RECORD`, deleting references), and
  never add the `snapshots-reviewed` label: that label is the user saying they compared
  the images, and the `Snapshot review` check waits for it.
- App identity changes in `Configs/Identity.xcconfig` only.

## Never

- add files to `project.pbxproj` by hand: `Pomelo/` and `PomeloUITests/` are buildable
  folders that pick up new files; put build settings in `Configs/*.xcconfig`, not the
  project
- add the package with Xcode's "Add Local…": Xcode builds that reference with
  `-suppress-warnings`, which breaks the build; `Pomelo.xcodeproj` references the
  package folder
- add Tuist or XcodeGen
- ship or test against `swift build` output; only `make app` and `make release` produce
  a valid `.app`
- use `ObservableObject`, `@Published`, `NavigationView` or `foregroundColor(_:)`
  (`make lint` rejects them)
- add SwiftLint or SwiftFormat beside `swift format`, a DI container or a networking
  library
- skip the git hooks (`--no-verify`, `LEFTHOOK=0`); fix what they report instead
- commit certificates, `.p12`/`.p8` files or the Sparkle private key
- edit `version.txt`, `.release-please-manifest.json` or `CHANGELOG.md` by hand;
  release-please owns them

## Add a feature

1. Add `Packages/AppModules/Sources/Features/<Name>/` with `<Name>View.swift` and
   `<Name>Model.swift`; `Features/Greeting/` is the pattern.
2. Declare it in `Packages/AppModules/Package.swift`: a `<Name>Feature` target with
   `path: "Sources/Features/<Name>"`, `resources: [.process("Resources")]` if it has
   strings and `swiftSettings: ui`; a `<Name>FeatureTests` test target at
   `Tests/Features/<Name>Tests` with `exclude: ["__Snapshots__"]` (SwiftPM warns about
   the reference PNGs otherwise); and `<Name>Feature` in `AppRoot`'s dependencies.
3. Add every user-facing string to the feature's `Resources/Localizable.xcstrings` in
   `en` and `zh-Hans`.
4. Work outside the process gets a service: protocol and mock in `Services`, live
   implementation in `ServicesLive` ([RECIPES](docs/RECIPES.md#networking) has one).
   `Pomelo/MainApp.swift` builds the live one and the mock under `UI_TESTING=1`, and
   passes it through `AppModel`.
5. `AppModel` owns the feature's model; `AppScenes` shows its view.
6. Test the model in `Tests/Features/<Name>Tests/` with mocks, and snapshot its view. A
   flow worth guarding end to end gets an XCUITest in `PomeloUITests/`.
7. New capability (network, files, camera…)? Add the entitlement to
   `Configs/App.entitlements` and its usage description as
   `INFOPLIST_KEY_NS…UsageDescription` in `Configs/App.xcconfig`.
8. `make ci`.

The Greeting demo (`Features/Greeting`, `GreetingModelTests`, `GreetingViewSnapshotTests`
and its `__Snapshots__`, `GreetingUITests`) is a placeholder; replace it with the first
real feature. Recipes for launch at login, networking, menu bar apps, global keyboard
shortcuts, AppKit bridges and crash reporting: [docs/RECIPES.md](docs/RECIPES.md).

Skills in `.agents/skills/`: `app-icon` makes the app icon. Skills that change the build
or the release start only when the user asks for them by name: `dmg` designs the DMG
window, `mac-app-store` adds an App Store build, `homebrew-cask` puts the app on
Homebrew.

## Commits and releases

Conventional Commits. PRs are squash-merged and the PR title becomes the commit on
`main`; CI checks it. release-please turns `feat` and `fix` commits into a release PR.
Merging it tags `vX.Y.Z` with a draft release, and the release workflow attaches the
DMG, dSYM and appcast, then publishes it. Details: [docs/RELEASING.md](docs/RELEASING.md).
