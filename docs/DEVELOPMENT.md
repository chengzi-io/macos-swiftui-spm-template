# Development

## Requirements

- Xcode 26 (Swift 6.2), selected with `xcode-select`. On macOS 26 or later, Xcode 26.3
  or later adds `xcrun mcpbridge`, through which coding agents build, test and render
  previews in Xcode. On macOS 15 it is installed but does not launch; `make doctor`
  says which case you are in.
- [lefthook](https://lefthook.dev) for git hooks: `brew install lefthook`
- The app runs on macOS 14 or later

```bash
make setup   # check the toolchain, install git hooks
make run     # build and launch the debug app
```

## How the app is built

```mermaid
flowchart LR
    pkg["Packages/AppModules<br/>all code, string catalogs,<br/>unit tests"] --> xb
    shell["App.xcodeproj + App/<br/>@main, assets, AppIcon.icon"] --> xb
    cfg["Configs/<br/>Identity.xcconfig, build settings,<br/>Info.plist, entitlements"] --> xb
    xb["xcodebuild<br/>compile, embed Sparkle,<br/>compile icon, sign"] --> app[".app"] --> smoke["scripts/smoke.sh<br/>check, launch"]
    pkg --> st["swift test<br/>unit tests, seconds"]
```

Xcode builds the app the way it builds any app; `scripts/build-app.sh` only adds the
version from `version.txt` and, for releases, archives a universal build and signs it
with the Developer ID. `swift test` builds the package alone, without the app, which
keeps the unit-test loop fast.

## Commands

`make help` lists every target.

- `make test` runs the unit tests: seconds, no app, no UI. Run it after every change.
- `make ci` runs lint, the unit tests, the debug `.app` and its launch smoke test. It is
  the definition of done.
- `make test:ui` runs the UI tests. On a Mac they drive the real mouse and keyboard,
  so the app comes to the front and types while they run: leave the machine alone until
  they finish. GitHub CI runs them after `make ci`. The first run asks for an
  administrator password to turn on Automation Mode, unless you turn it on once with
  `sudo automationmodetool enable-automationmode-without-authentication`.

Try the Chinese UI with `make run ARGS="-AppleLanguages '(zh-Hans)'"`.

## Layout

```text
App.xcodeproj/             the shell: App and AppUITests targets, shared App scheme
App/                       @main (composition root), app delegate, assets, AppIcon.icon,
                           privacy manifest
AppUITests/                XCUITest: a few critical flows
Configs/                   Identity.xcconfig (app identity), build settings, Info.plist,
                           entitlements
Packages/AppModules/       the local Swift package with all the code
  Package.swift            targets, platforms, Swift settings, Sparkle
  Sources/AppRoot/         root model, scenes, menu commands
  Sources/Features/<Name>/ one target per feature: view, model, string catalog
  Sources/Services/        protocols for what reaches outside the process, and mocks
  Sources/ServicesLive/    the live implementations: system APIs, network, Sparkle
  Tests/                   Swift Testing, mirroring Sources/
scripts/                   build, sign, notarize, package, publish, lint rules
.agents/skills/            agent skills, linked from .claude/skills
.github/                   CI, PR title, release-please, Dependabot, templates
version.txt                current version, owned by release-please
```

Where code goes and the rules it follows: [AGENTS.md](../AGENTS.md).

## Editors

- Xcode: `xed App.xcodeproj`. Its Run button builds and launches the real `.app`
  (bundle identifier, sandbox, Info.plist), with the debugger attached. Previews run
  in the package targets.
- VS Code / Cursor: the Swift extension (sourcekit-lsp) works on
  `Packages/AppModules`; build and run the app with `make run`.

## Agent skills

Skills live in `.agents/skills` (Codex and other agents), linked from `.claude/skills`
(Claude Code).

- `app-icon`: the app icon, from your logo or image, as drawn layers, or through an
  image-model prompt; it renders every appearance and sets the icon beside installed
  apps. Agents start it when you ask for an icon.
- `dmg`: designs the DMG window, from plain to a branded illustration, and wires
  dmgbuild into the build when you start it. Only you start it: `/dmg` in Claude Code,
  `$dmg` in Codex.
- `mac-app-store`: adds a Mac App Store build, beside the Sparkle release or instead of
  it, and wires it into the build and the code. Only you start it.
- `homebrew-cask`: puts the app on Homebrew: in the official `homebrew/cask`, which
  needs a Developer ID and a notable repository and then updates the cask by itself, or
  in your own tap, which every release updates and which also takes ad-hoc builds. Only
  you start it.

## Commits and releases

PR titles are Conventional Commits ([CONTRIBUTING](../.github/CONTRIBUTING.md)); PRs are
squash-merged, and release-please turns `feat` and `fix` into releases. The flow and the
one-time setup: [RELEASING.md](RELEASING.md). Recipes for launch at login, networking,
menu bar apps and crash reporting: [RECIPES.md](RECIPES.md).
