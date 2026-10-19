# AGENTS.md

macOS SwiftUI app built from a pure Swift package: no `.xcodeproj`. `Package.swift`
compiles the code; `scripts/` assembles, signs and ships the `.app`. Setup, the
command table and the layout live in [README.md](README.md); this file is the rules
of engagement.

## Gate commands

```bash
make ci      # definition of done: format lint, unit tests, debug .app, launch smoke test
make run     # build and launch the debug app; logs go to the terminal (or .build/app/run.log)
make fmt     # format Swift sources (the pre-commit hook formats staged files too)
```

Toolchain: Xcode 26 (Swift 6.2); the app targets macOS 14+. `make doctor` checks it.

## Where things go

- `Sources/App/`: `@main`, scenes, menu commands, the app delegate and Sparkle. Assembly
  only.
- `Sources/AppCore/`: views, `@Observable` models, services. Previews and tests run here.
- `Sources/AppCore/Resources/`: `Localizable.xcstrings` (en, zh-Hans) and package assets.
- `Tests/AppCoreTests/`: Swift Testing.
- `Bundle/`: packaging input, not SwiftPM resources. `app.env` (app identity),
  `Info.plist`, `App.entitlements`, `PrivacyInfo.xcprivacy`, `AppIcon.icon` (edit it in
  Icon Composer) and the accent color in `Assets.xcassets`.
- `scripts/`: build, sign, notarize, package, publish. The Makefile only calls them.
- Add a target only for a real boundary (a separate domain, a reusable component),
  never ahead of need.

## Rules

- Package resources need `bundle: .module`: `Text("Key", bundle: .module)`,
  `String(localized: "Key", bundle: .module)`, `Image("name", bundle: .module)`.
  Without it SwiftUI looks in the main bundle and shows the raw key; nothing fails at
  compile time.
- Code is MainActor by default (`.defaultIsolation(MainActor.self)`). Mark background
  work `@concurrent` or `nonisolated` explicitly.
- Under that default `Bundle.module` is MainActor-isolated, so nonisolated code (Error
  types, Sendable values) cannot read it. Resolve user-facing text in views or models,
  as `GreeterError.message` does.
- Value types decoded or passed off the main actor need `nonisolated struct …: Codable,
  Sendable`; otherwise their conformances are MainActor-isolated too.
- Warnings are errors (`.treatAllWarnings(as: .error)`). Fix them; do not silence them.
- Errors: each service throws its own `enum …Error: Error`; the model catches once,
  logs, and turns the error into state the view shows. No empty `catch`, no `try?` on
  errors that matter.
- Logging: `Log.app` / `Log.ui` (`os.Logger`, subsystem = bundle identifier). Dynamic
  values stay private unless marked `privacy: .public`; never log tokens or personal
  data. `make logs` streams them.
- State: `@Observable` models injected with `.environment(...)`. Services are protocols
  passed through initializers; `Sources/App` builds the live ones, tests pass stubs.
- Tests: Swift Testing (`@Test`, `#expect`) on `AppCore` models and services.
  `swift test` does not compile asset or string catalogs, so unit tests never assert
  localized text or images; `make smoke` covers resources in the real `.app`.
- App identity (name, bundle id, team, release URL) changes in `Bundle/app.env` only.

## Never

- add an `.xcodeproj`, Tuist or XcodeGen
- ship or test against `swift build` output; only `make app` and `make release` produce
  a valid `.app`
- add SwiftLint or SwiftFormat beside `swift format`, a DI container or a networking
  library
- commit certificates, `.p12`/`.p8` files or the Sparkle private key
- edit `version.txt`, `.release-please-manifest.json` or `CHANGELOG.md` by hand;
  release-please owns them

## Add a feature

1. Add `Sources/AppCore/<Feature>/` with the view, its `@Observable` model and a
   service protocol plus its live implementation. `Greeting/` with `AppModel` and
   `ContentView` is the pattern.
2. Add every user-facing string to `Localizable.xcstrings` in `en` and `zh-Hans`.
3. Build the live service in `Sources/App/MainApp.swift` and inject it.
4. Test the model with a stub service in `Tests/AppCoreTests/`.
5. New capability (network, files, camera…)? Add the entitlement to
   `Bundle/App.entitlements` and any `NS…UsageDescription` to `Bundle/Info.plist`.
6. `make ci`.

The Greeter demo (`Greeting/`, `AppModel`, `ContentView`, `AppModelTests`) is a
placeholder; replace it with the first real feature. Recipes for launch at login,
networking, menu bar apps and crash reporting: [docs/RECIPES.md](docs/RECIPES.md). App
icon design: [.claude/skills/brand/SKILL.md](.claude/skills/brand/SKILL.md). The DMG
window has its own skill, `/dmg` ([.claude/skills/dmg](.claude/skills/dmg/SKILL.md)),
which only the user starts.

## Commits and releases

Conventional Commits. PRs are squash-merged and the PR title becomes the commit on
`main`; CI checks it. release-please turns `feat` and `fix` commits into a release PR;
merging it tags `vX.Y.Z` and the release workflow publishes the DMG, dSYM and appcast.
Details: [docs/RELEASING.md](docs/RELEASING.md).
