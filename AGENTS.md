# AGENTS.md

macOS SwiftUI app. All code lives in the Swift package at the repository root
(`Package.swift`, `Sources/`, `Tests/`); a thin Xcode project, `App/<App>.xcodeproj`,
builds, signs and packages the app; `scripts/` ships it. `<App>` stands for the app's
name (`APP_NAME`), which the package, the project, its app target and the scheme carry.
Setup and the layout live in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md), the commands
in `make help`; this file is the rules of engagement.

<!-- template-only:start -->
## Before init

`scripts/init.sh` has not run, so this repository is still the template and `README.md`
describes the template. When the user asks for app work (a feature, an icon, a
release), first ask for the app name and bundle identifier, run
`scripts/init.sh --name <Name> --bundle-id <id>` on a clean tree, show the user the
`git diff HEAD` (renames are staged) and commit it as
`chore: initialize <Name> from template`. Then `make setup`;
`make snapshots`, which records the demo's view snapshots on this Mac (init removed the
template's): show the user the images and commit them after their yes; then `make ci`.
The one-time release setup in [docs/RELEASING.md](docs/RELEASING.md) needs the user's
GitHub and Apple accounts, so it stays with them. When the user is
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
Package.swift                 the package <App>: targets, dependencies, Swift settings
Sources/
  AppRoot/                    AppModel (root of the model tree), AppScenes (windows,
                              commands, Settings), app-wide menus
  Features/<Name>/            target <Name>Feature: one area of the app, its screens (a
                              folder each when there are several), <Name>Model, logic
                              only it uses, Resources/Localizable.xcstrings
  Platform/                   what any Mac app needs from the system: updates, launch
                              at login, notifications, preferences
    Core/<Name>/              target Platform: a protocol for each thing outside the
                              process, its types, its error enum and a Mock<Name>Service
    Live/<Name>/              target PlatformLive: Live<Name>Service (system APIs,
                              network, files, Sparkle)
Tests/                        Swift Testing, mirroring Sources/ (<Name>FeatureTests);
                              SnapshotSupport renders views for the snapshot tests
App/                          the Xcode shell: <App>.xcodeproj, targets <App> and
                              <App>UITests
  Application/                @main, the composition root: builds the live services
                              (mocks under UI_TESTING=1) and hands them to AppRoot.
                              Plus the app delegate, assets, AppIcon.icon. No views.
  UITests/                    XCUITest, a few critical flows; launches with UI_TESTING=1
  Configs/Identity.xcconfig   app identity (name, bundle id, team, repository): only here
  Configs/*.xcconfig          build settings; Info.plist and App.entitlements beside them
  Package.swift               empty: keeps App/ out of the root package in Xcode
```

Create these the first time something needs them, not before:

- `Sources/<Domain>/` for what this app is about (`Monitor`, `Library`, `Sync`), split
  as `Platform` is: `Core/<Name>/` is target `<Domain>` (protocols, value types, pure
  logic and models that several features share, mocks), `Live/<Name>/` is target
  `<Domain>Live`. A domain with nothing outside the process has no `Live/`. A domain is
  a group of capabilities that change together, not one per service. Its tests:
  `<Domain>Tests` in `Tests/<Domain>Tests/`.
- `Sources/DesignSystem/` for the app's look, once it picks its own: the spacing, corner
  radii, fonts and colors it repeats, and components several screens share
  (`StatusBadge(level:)`). It knows no domain: a feature maps its data onto it, and a
  component that shows a domain's data stays in its feature. System styles (`Form`,
  `.font(.headline)`, `.secondary`) get no token. Colors go in code
  (`NSColor(name:dynamicProvider:)`), not an asset catalog; the accent color stays the
  empty `AccentColor` in `App/Application/Assets.xcassets`, never `.tint`
  ([why](docs/ARCHITECTURE.md#the-apps-look)).
- `Sources/Kits/<Name>/` for code that knows nothing of this app: a wrapper of a C or
  private interface, or `AppKitBridge` for `NSViewRepresentable` wrappers and NSWindow
  or NSEvent helpers ([RECIPES](docs/RECIPES.md#appkit-bridges)).
- An extension or helper (a widget, a login item) is another thin target in
  `App/<Name>/`, linking the domain Cores and the Live it needs, never a feature or
  `AppRoot`; its views go in a package target of their own.

What the user sees is a feature; what any Mac app needs is `Platform`; what this app is
about is a domain; what knows nothing of this app is a kit. A target is one folder
tree, and two targets' folders cannot nest (SwiftPM reports overlapping sources): hence
`Core/` and `Live/` side by side, each grouped by capability.

A feature is an area the user works in, not a screen: screens that show the same data
and change together (a menu bar item and its panel) share a target, a folder each.
Split a target when part of it changes for other reasons. A grown app has some 8 to 15
library targets; more usually means folders were made into modules.

Dependencies, enforced by `Package.swift` (`make test` fails on an import a target does
not declare):

```text
<App>          ──► AppModules: AppRoot, <Domain>, <Domain>Live, Platform, PlatformLive
AppRoot        ──► <Name>Feature, <Domain>, Platform
<Name>Feature  ──► <Domain>, Platform, DesignSystem, Kits
<Domain>       ──► another <Domain>, Platform, Kits
…Live          ──► its Core, other Cores, Kits; never another Live
DesignSystem   ──► Kits
```

A feature never depends on another feature; only `<App>` knows the live services. A
domain never depends on another in a cycle; a kit depends on no module of the app. A
flow that spans domains and runs without a screen (a reading crosses a threshold, so
notify) belongs to the domain that consumes the others' results, named for what it does
(`Alerts` uses `Monitor`'s readings and `Platform`'s notifications), with the decision
as a plain type; not to a Live, `MainApp` or a screen's model. Why, with a menu bar
monitor as the example: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

`README.md` is the app's page for its users; developer docs go in `docs/`. Skills live
in `.agents/skills/`, and `.claude/skills/` links to each one: link a new skill the
same way.

## Rules

- Something outside the process (system API, network, files, UserDefaults, Keychain,
  the clock) that a model needs is a service: protocol and mock in the Core of
  `Platform` or its domain, live implementation in the matching Live. Pure logic
  (formatting, parsing, calculation, state machines) stays a plain type the model calls
  directly, as `WordCount` is; it gets no protocol. For time, take `any Clock<Duration>`.
  A package that owns the outside access, its storage and the control the user sees,
  with no logic of the app's in between, gets no service (KeyboardShortcuts in
  [RECIPES](docs/RECIPES.md#global-keyboard-shortcuts)): a model test would have nothing
  to swap. SwiftData is the other exception, since `@Query` keeps a view's list current:
  the scene sets `.modelContainer(...)`, a view reads with `@Query` and never writes, its
  feature's model inserts, deletes and saves through a `ModelContext`, and tests,
  previews and snapshots use an in-memory store instead of a mock
  ([RECIPES](docs/RECIPES.md#swiftdata)).
- Models are `@Observable` and reach views through initializers, never
  `.environment(...)`: a missing initializer argument fails the build, a missing
  environment object crashes at run time. A feature's `<Name>Model` owns its screens'
  models and the state they share (the selection). `AppModel` owns the features'
  models, the models a domain shares among features, and what is app-wide (the updater,
  a global shortcut): a new screen changes its feature's model, not `AppModel`.
- Every view has a `#Preview` built from mocks.
- Package resources need `bundle: .module`: `Text("Key", bundle: .module)`,
  `String(localized: "Key", bundle: .module)`, `Image("name", bundle: .module)`.
  Without it SwiftUI looks in the main bundle and shows the raw key; nothing fails at
  compile time. Each target with strings has its own `Localizable.xcstrings` (en,
  zh-Hans).
- Feature targets and AppRoot are MainActor by default; `Platform`, the domains and
  their Live targets are not. Mark UI-bound services and a domain's models
  `@MainActor`, and background work `@concurrent`: a plain `nonisolated async` function
  runs on its caller's actor.
- In MainActor-by-default targets `Bundle.module` is MainActor-isolated, so nonisolated
  code (Error types, Sendable values) cannot read it. Resolve user-facing text in views
  or models, as `NoteError.message` in `NotesModel.swift` does. Value types decoded or
  passed off the main actor there need `nonisolated struct …: Codable, Sendable`.
- Warnings are errors, in the package and in the app. Fix them; do not silence them.
  `MemberImportVisibility` is on: import every module whose members a file uses
  (`import OSLog` for `Logger` interpolation).
- Errors: each service throws its own `enum …Error: Error`; the model catches once,
  logs, and turns the error into state the view shows. No empty `catch`, no `try?` on
  errors that matter.
- Logging: each module has an internal `Log` enum of `os.Logger`s with its own category
  (`Log.notes`); subsystem = bundle identifier. Dynamic values stay private unless
  marked `privacy: .public`; never log tokens or personal data. `make logs` streams
  them.
- Feature modules end in `Feature` (`SettingsFeature`), and no module is named after a
  SwiftUI type: a module called `Settings` or `App` breaks `Settings.SomeType` lookups.
- Tests: Swift Testing (`@Test`, `#expect`) on models and services, with mocks for
  every service. A live service with logic of its own (a missing file read as empty, a
  status code turned into an error) is also tested against the real thing, in a
  temporary directory or against a local stub, in its domain's test target
  (`LiveNoteServiceTests`); what it reaches comes in through its initializer, defaulting
  to the real one. One that only hands calls to a framework, as the updater does, needs
  no such test. `swift test` does not compile asset or string catalogs, so unit tests
  never assert localized text or images; `make smoke` covers resources in the real
  `.app`. XCTest only for UI tests.
- Screens get snapshot tests (swift-snapshot-testing; `NotesViewSnapshotTests` is the
  pattern): each screen in the states that tell it apart (empty, filled, an error shown
  in the view), light and dark, in English; a subview shows in its screen's snapshot. An
  `.alert` or a sheet has no window to draw in, so it never shows in one.
  `SnapshotSupport`'s `render` draws them at 2x through `NSHostingView`, with controls
  in the default blue accent and scroll bars hidden, whatever the Mac's settings and the
  app's accent. The PNGs in `__Snapshots__/` beside the test are how an agent sees a view
  without Xcode: read them. Tests never record: a missing or changed reference fails, and
  the failure names the reference and the new image.
- Recording a snapshot is the user's call. When one fails after a change you meant to
  make, or a new test has no reference, read the old and the new image, show the user
  what changed, and wait for their yes; then `make snapshots` (Claude Code asks too).
  Never record any other way (`SNAPSHOT_TESTING_RECORD`, deleting references), and
  never add the `snapshots-reviewed` label: that label is the user saying they compared
  the images, and the `Snapshot review` check waits for it.
- App identity changes in `App/Configs/Identity.xcconfig` only. The name, display name
  and bundle identifier change only through `scripts/rename.sh`, which renames the
  package, project, targets and scheme with them, and only before the first release:
  after it, they would make a different app.

## Never

- edit `project.pbxproj` by hand: `App/Application/` and `App/UITests/` are buildable
  folders that pick up new files; put build settings in `App/Configs/*.xcconfig`, not
  the project; the app target links one package product, `AppModules`, which lists
  every module `MainApp` imports
- add the package with Xcode's "Add Local…": Xcode builds that reference with
  `-suppress-warnings`, which breaks the build; `App/<App>.xcodeproj` references the
  repository root as a folder
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

1. Add `Sources/Features/<Name>/` with `<Name>View.swift` and `<Name>Model.swift`;
   `Features/Notes/` is the pattern. A new screen of an existing area goes in that
   feature's folder, not a new target.
2. Declare it in `Package.swift`: a `<Name>Feature` target with
   `path: "Sources/Features/<Name>"`, `resources: [.process("Resources")]` if it has
   strings and `swiftSettings: ui`; a `<Name>FeatureTests` test target at
   `Tests/Features/<Name>Tests` that depends on the feature, the Cores it uses,
   `SnapshotSupport` and the `SnapshotTesting` product, with `exclude: ["__Snapshots__"]`
   (SwiftPM warns about the reference PNGs otherwise), as `NotesFeatureTests` does; and
   `<Name>Feature` in `AppRoot`'s dependencies. `make feature NAME=<Name>` creates the
   feature's files and prints these blocks. Add the test target to the `<App>`
   scheme's Test action (Xcode: Product → Scheme → Edit Scheme… → Test → +) so ⌘U runs
   it; `make test` runs it either way, and `make lint` fails until the scheme lists it.
   Without Xcode, copy the `NotesFeatureTests`
   `<TestableReference>` in `App/<App>.xcodeproj/xcshareddata/xcschemes/<App>.xcscheme`
   and change its three names.
3. Add every user-facing string to the feature's `Resources/Localizable.xcstrings` in
   `en` and `zh-Hans`.
4. Work outside the process gets a service: protocol and mock in `Platform/Core/` or a
   domain's `Core/`, live implementation in the matching `Live/`
   ([RECIPES](docs/RECIPES.md#networking) has one).
   `App/Application/MainApp.swift` builds the live one and the mock under
   `UI_TESTING=1`, and passes it through `AppModel`. A new domain's two targets join
   the `AppModules` product in `Package.swift`, which the app links; the Xcode project
   does not change. The composition stays in `MainApp`: which updater an app gets
   depends on its Xcode target (an App Store build carries no Sparkle), and package
   targets cannot see a target's build settings.
5. `AppModel` owns the feature's model; `AppScenes` shows its view.
6. Test the model in `Tests/Features/<Name>Tests/` with mocks, and snapshot its
   screens. A flow worth guarding end to end gets an XCUITest in `App/UITests/`.
7. New capability (network, files, camera…)? Add the entitlement to
   `App/Configs/App.entitlements` and its usage description as
   `INFOPLIST_KEY_NS…UsageDescription` in `App/Configs/App.xcconfig`.
8. `make ci`.

The Notes demo is a placeholder: the `Notes` domain (`Sources/Notes`), `Features/Notes`,
`NotesTests`, `NotesFeatureTests` and its `__Snapshots__`, `NotesUITests`, and their
lines in `Package.swift` (its targets and their place in `AppModules`), the `<App>`
scheme's Test action, `AppModel`, `AppScenes` and `MainApp.swift`. Replace it with the
first real feature, and point this file's examples (`WordCount`, `NoteError.message`,
`Log.notes`, `NotesViewSnapshotTests`, `LiveNoteServiceTests`, `NotesFeatureTests`,
`Features/Notes/`) at their counterparts in it. Recipes for launch at login,
networking, menu bar apps, global keyboard shortcuts, AppKit bridges, crash reporting,
the Keychain, SwiftData and the privacy manifest: [docs/RECIPES.md](docs/RECIPES.md).

Skills in `.agents/skills/`: `app-icon` makes the app icon. Skills that change the build
or the release start only when the user asks for them by name: `dmg` designs the DMG
window, `mac-app-store` adds an App Store build, `homebrew-cask` puts the app on
Homebrew.

## Commits and releases

Conventional Commits. PRs are squash-merged and the PR title becomes the commit on
`main`; CI checks it. release-please turns `feat` and `fix` commits into a release PR.
Merging it tags `vX.Y.Z` with a draft release, and the release workflow attaches the
DMG, dSYM and appcast, then publishes it. Details: [docs/RELEASING.md](docs/RELEASING.md).
