---
name: add-feature
description: Add a feature to this app - a new area the user works in, as a <Name>Feature target with its model, view, strings, render tests and scheme entry - and wire it into AppRoot. Use when the user asks for a new screen, window, panel or area of the app, or for a service a feature needs (network, files, a system API).
---

# Add feature

Adds one `<Name>Feature` target end to end, and ends with `make ci` green.
`scripts/scaffold.sh` writes the files and the scheme entry; the `Package.swift`
blocks and the wiring are printed for you to paste, so they stay a reviewed edit.
`<skill>` is `.agents/skills/add-feature`; its scripts run from anywhere inside the
project. `<App>` is `APP_NAME` in `App/Configs/Identity.xcconfig`.

## Status

Moves the `make status` demo line from `todo demo` to `ok demo`. The first feature takes
the Notes demo's place: `scripts/remove-demo.sh` removes it. A later feature leaves the
line as it is.

## Before you start

- `make status`: the setup and project lines are `ok`.
- `xmllint` is installed; it ships with macOS.

## Plan

Say what will change and wait for the user's go-ahead.

A feature is an area the user works in, with its own data (a library, an inspector).
Another screen of an area that exists (a detail view of Notes) goes in that feature's
folder and model, with no new target. Work outside the process is a service (step 5).
Something every Mac app has (updates, login item) belongs in `Platform`.

A feature never depends on another feature; only `AppRoot` puts features together.
`Sources/Features/Notes/` is the pattern to copy while the demo is still there.

## Steps

### 1. Name it

`<Name>` is the area, capitalized, without `Feature` (`Library` makes `LibraryFeature`).
Agree on it with the user if the request does not say.

### 2. Scaffold

`<skill>/scripts/scaffold.sh <Name>`. It refuses a name in use, a lowercase one and one
whose logger would be a Swift keyword; pick another name, do not create the files by
hand. It prints three `Package.swift` blocks and the files it wrote
([what it makes](references/scaffold-output.md)).

### 3. Replace the Notes demo (first feature only)

While `Sources/Features/Notes` exists, the demo goes: it is the template's, not the app's.

1. `<skill>/scripts/remove-demo.sh --dry-run`; show the user its `would …` lines.
2. Run it without `--dry-run`. It removes the Notes domain, feature, tests and UI test,
   their targets in `Package.swift` and the scheme, and rewrites `AppModel`,
   `AppScenes` and `MainApp.swift` to an empty window. It says `done already` for a step
   whose result is in place.
3. It fails while `Package.swift` still names Notes: fix the lines it prints, then run it
   again.

The new feature is wired where the demo was, in step 6.

### 4. Declare it in `Package.swift`

Paste the blocks the scaffold printed:

- the `<Name>Feature` target after the other features, with the Cores it uses in
  `dependencies:` and `swiftSettings: ui`;
- the `<Name>FeatureTests` test target after the other feature tests, depending on
  the feature, the Cores its tests use and `RenderSupport`, as the scaffold
  printed it;
- `"<Name>Feature"` in `AppRoot`'s `dependencies`.

`make lint` fails while the scheme and `Package.swift` disagree on test targets, and
`swift test` fails on an import of a target that is not declared.

### 5. Services

Work outside the process gets a service: the protocol and its mock in
`Domains/Platform/` or a domain's folder, the live implementation in the matching
`Domains/<Name>Live/` ([recipe: networking](../add-capability/references/networking.md)).
`App/Application/MainApp.swift` builds the live one, and the mock under `UI_TESTING=1`,
and passes it through `AppModel`. A new domain's two targets join the `AppModules`
product in `Package.swift`; the Xcode project does not change.

### 6. Wire it

`AppModel` owns `<Name>Model`; `AppScenes` shows `<Name>View` (in an existing window, a
new `Window` or `WindowGroup`, or `Settings`). A new screen later changes the feature's
model, not `AppModel`.

### 7. Build the feature

Model logic in the model, layout in the view. Every user-facing string goes in
`Text("…", bundle: .module)` and the feature's `Localizable.xcstrings`.

### 8. Translate

For each locale in `REQUIRED_LOCALES` (`App/Configs/Identity.xcconfig`) except `en`, give
every string a value and set its `state` to `translated`. `make lint` fails on a `new` or
missing one.

### 9. Test

In `Tests/Features/<Name>Tests/`: the model's logic with the Cores' mocks passed through
`init`, and a render test per state worth seeing. Look at the PNGs in
`.build/renders/<Name>ViewRenderTests/`. A flow worth guarding end to end gets an
XCUITest in `App/UITests/`.

### 10. Capabilities

Network, files, camera and the like: add the entitlement to `App/Configs/App.entitlements`
and its usage description as `INFOPLIST_KEY_NS…UsageDescription` in
`App/Configs/App.xcconfig`.

### 11. Verify

`make ci`. Show the user the renders of the new view. A failing check and its fix:
[scaffold output and fixes](references/scaffold-output.md).

## Changes

| File | Change |
| --- | --- |
| `Sources/Features/<Name>/`, `Tests/Features/<Name>Tests/` | created by the scaffold |
| `App/<App>.xcodeproj/xcshareddata/xcschemes/<App>.xcscheme` | `<Name>FeatureTests` added to the Test action |
| `Package.swift` | the feature and test targets, and `AppRoot`'s dependency |
| `AppRoot/AppModel.swift`, `AppRoot/AppScenes.swift` | the model and the view wired in; `remove-demo.sh` rewrites both, first feature only |
| `App/Configs/App.entitlements`, `App/Configs/App.xcconfig` | only for a capability (step 10) |

## The user's part

- Pick the area's name when the request does not name it.
- Approve the plan, and look at the renders of the new view before it ships.

## Done when

- `make test` passes, then `make ci` exits 0; the user has seen the renders.
- `make status` shows `ok demo`.

## Never

- Add files or settings to `App/<App>.xcodeproj` for a feature: the package carries it.
- Make one feature depend on another, or a feature depend on a `Live` target.
- Pass a model through `.environment`: pass it through `init`.
- Leave a scaffolded string untranslated or delete it from the catalog to pass lint.
- Run `remove-demo.sh` without `--dry-run` first, or after wiring the new feature into
  `AppModel` and `AppScenes`: it rewrites both files.
