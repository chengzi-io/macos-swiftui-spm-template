---
name: macos-recipes
description: Worked recipes for macOS capabilities this template leaves out until an app needs them - launch at login, networking, a menu bar app, global keyboard shortcuts, AppKit bridges, crash reporting, Keychain and files, SwiftData, the privacy manifest. Use when the user asks for one of these, or a task needs one (an HTTP request, a login item, a hotkey, a window SwiftUI cannot shape, persisted data).
---

# macOS recipes

Each recipe is one file in `references/`, with code that fits this repository's layers.
Read only the one the task needs; they do not depend on each other except where a
recipe links another.

`<skill>` is this skill's directory, `.agents/skills/macos-recipes`. `<Name>` and
`<App>` mean what they mean in the root `AGENTS.md`.

## Recipes

| Recipe | Read when | Lands in |
| --- | --- | --- |
| [Launch at login](references/launch-at-login.md) | the app should start when the user logs in | `Platform` service, a General pane in `Features/Settings` |
| [Networking](references/networking.md) | anything talks HTTP: an API, a download, release notes | a domain's Core protocol and mock, its Live `URLSession` service |
| [Menu bar app](references/menu-bar.md) | a menu bar item beside the window, or a menu-bar-only app | `AppRoot` (`MenuBarMenu`, `AppScenes`), `App/Configs/App.xcconfig` |
| [Global keyboard shortcuts](references/keyboard-shortcuts.md) | a shortcut that works while another app is frontmost | the KeyboardShortcuts package, `Features/Settings`, `AppModel` |
| [AppKit bridges](references/appkit-bridges.md) | SwiftUI has no API for a view, a window property or a window's structure | `Sources/Kits/AppKitBridge`, or an `NSWindowController` in `AppRoot` |
| [Crash reporting](references/crash-reporting.md) | the app has users and crashes must reach you | Sentry in `PlatformLive`, or MetricKit |
| [Keychain, data and files](references/keychain-and-storage.md) | the app stores a token, a password, records or files | a Keychain service; [SwiftData](references/swiftdata.md); Application Support |
| [SwiftData](references/swiftdata.md) | the app keeps records the user browses and edits | `@Model` types in a domain Core, the feature's model, `MainApp` |
| [Privacy manifest](references/privacy-manifest.md) | code or an SDK uses a required-reason API or collects data | `App/Application/PrivacyInfo.xcprivacy` |

## Procedure

1. **Pick the recipe** from the table and read its reference. When none fits, follow
   `Sources/AGENTS.md` and do not invent a pattern here.
2. **Read the rules it relies on**: `Sources/AGENTS.md` (layers, services, strings,
   errors) and, for `App/` changes, `App/AGENTS.md`. A recipe never overrides them.
3. **Adapt the names.** The recipes use examples (`ReleaseNotes`, `Library`,
   `Bookmark`, `showApp`); name types after what the app does, and put them in the
   domain they belong to, not `Platform`, unless every Mac app would need them.
4. **A new feature target** goes through the add-feature skill
   ([SKILL.md](../add-feature/SKILL.md)); the recipe then fills it in.
5. **A new package** (KeyboardShortcuts, Sentry) needs the user's yes first; pin it
   `exact:` in `Package.swift`, as the recipe shows.
6. **Strings** the recipe adds go in the target's `Localizable.xcstrings`, translated
   into every locale of `REQUIRED_LOCALES` (`App/Configs/Identity.xcconfig`).
7. **Tests**: the model with the Core mock (or an in-memory store for SwiftData), a
   `#Preview` built from mocks, render tests for a new view. Never the network or the
   real system state.
8. `make test` while working, `make ci` at the end. Check what only the installed app
   shows (a login item, a hotkey, a menu bar item) with `make run` or in `/Applications`,
   and tell the user what you could not check.

## Shared rules

Every recipe keeps these; the references do not repeat them.

- Anything outside the process is a service: protocol, error enum and mock in a Core,
  the live type in the matching Live, passed in through an initializer. KeyboardShortcuts
  and SwiftData are the two exceptions, and their recipes say why.
- The model catches an error once, logs it with the module's `Log`, and turns it into
  state the view shows.
- `MainApp` builds the live services, and the mocks under `UI_TESTING=1`.

## Never

- Copy a recipe without adapting names and placement, or keep its example strings.
- Add a package, an entitlement or a privacy-manifest entry the recipe does not need.
- Swizzle, call private API, or poll to reapply a window value (see AppKit bridges).
- Leave a recipe half-wired: a service no model uses, or a string missing a locale.
