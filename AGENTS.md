# AGENTS.md

macOS SwiftUI app built from a pure Swift package: no `.xcodeproj`. `Package.swift`
compiles the code; `scripts/` assembles, signs and ships the `.app`. Setup and the
layout live in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md), the commands in `make help`;
this file is the rules of engagement.

<!-- template-only:start -->
## Before init

`scripts/init.sh` has not run, so this repository is still the template and `README.md`
describes the template. When the user asks for app work (a feature, an icon, a
release), first ask for the app name and bundle identifier, run
`scripts/init.sh --name <Name> --bundle-id <id>` on a clean tree, show the user the
`git diff` and commit it as `chore: initialize <Name> from template`; then `make setup`
and `make ci`. The one-time release setup in [docs/RELEASING.md](docs/RELEASING.md)
needs the user's GitHub and Apple accounts, so it stays with them. When the user is
changing the template itself, leave init alone. Init removes this section.
<!-- template-only:end -->

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
- `README.md`: the app's page for the people who use it, what it does and how to
  install it. Developer docs go in `docs/`: `DEVELOPMENT.md` (setup, commands, layout),
  `RELEASING.md`, `RECIPES.md`.
- `.agents/skills/`: agent skills; Codex and other agents read this directory. Claude
  Code reads `.claude/skills/`, which links to each one: link a new skill the same way.
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
- State: `@Observable` models injected with `.environment(...)`. A service that reaches
  outside the process (network, files, system APIs, the clock) is a protocol passed
  through the model's initializer: `Sources/App` builds the live one, tests pass a stub
  ([RECIPES](docs/RECIPES.md#networking) has one). Pure logic stays a plain type the
  model calls directly, as `Greeter` is.
- AppKit: only where no SwiftUI API does the job, bridged at the layer that is missing:
  a view, a window property or the window's structure
  ([RECIPES](docs/RECIPES.md#appkit-bridges)). No swizzling, private API or polling.
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
- skip the git hooks (`--no-verify`, `LEFTHOOK=0`); fix what they report instead
- commit certificates, `.p12`/`.p8` files or the Sparkle private key
- edit `version.txt`, `.release-please-manifest.json` or `CHANGELOG.md` by hand;
  release-please owns them

## Add a feature

1. Add `Sources/AppCore/<Feature>/` with the view and its `@Observable` model;
   `Greeting/` with `AppModel` and `ContentView` is the pattern. Work that reaches
   outside the process gets a service protocol and its live implementation.
2. Add every user-facing string to `Localizable.xcstrings` in `en` and `zh-Hans`.
3. Build the model, and any live service it takes, in `Sources/App/MainApp.swift` and
   inject it.
4. Test the model in `Tests/AppCoreTests/`, with a stub for each service protocol.
5. New capability (network, files, camera…)? Add the entitlement to
   `Bundle/App.entitlements` and any `NS…UsageDescription` to `Bundle/Info.plist`.
6. `make ci`.

The Greeter demo (`Greeting/`, `AppModel`, `ContentView`, `AppModelTests`) is a
placeholder; replace it with the first real feature. Recipes for launch at login,
networking, menu bar apps and crash reporting: [docs/RECIPES.md](docs/RECIPES.md).

Skills in `.agents/skills/`: `app-icon` makes the app icon. Skills that change the build
or the release start only when the user asks for them by name: `dmg` designs the DMG
window, `mac-app-store` adds an App Store build, `homebrew-cask` puts the app on
Homebrew.

## Commits and releases

Conventional Commits. PRs are squash-merged and the PR title becomes the commit on
`main`; CI checks it. release-please turns `feat` and `fix` commits into a release PR.
Merging it tags `vX.Y.Z` with a draft release, and the release workflow attaches the
DMG, dSYM and appcast, then publishes it. Details: [docs/RELEASING.md](docs/RELEASING.md).
