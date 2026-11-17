---
name: add-feature
description: Add a feature to this app - a new area the user works in, as a <Name>Feature target with its model, view, strings, render tests and scheme entry - and wire it into AppRoot. Use when the user asks for a new screen, window, panel or area of the app, or for a service a feature needs (network, files, a system API).
---

# Add feature

Adds one `<Name>Feature` target end to end, and ends with `make ci` green. `make feature`
writes the files and declares them in `Package.swift` and the scheme; the two lines that
wire it and the translation are yours, and `make lint` fails until they are done.
`<App>` is `APP_NAME` in `App/Configs/Identity.xcconfig`.

## Plan

Say what will change and wait for the user's go-ahead.

A feature is an area the user works in, with its own data (a library, an inspector).
Another screen of an area that exists (a detail view of the readings) goes in that
feature's folder and model, with no new target. Work outside the process is a service
([recipe: networking](../add-capability/references/networking.md)). Something every Mac
app has (updates, login item) belongs in `Platform`.

`<Name>` is the area, capitalized, without `Feature` (`Library` makes `LibraryFeature`).
Where the screen goes decides the view line of step 4: an existing window, a new `Window`
or `WindowGroup`, or `Settings`.

## Steps

### 1. Name it

Agree on `<Name>` with the user if the request does not name the area.

### 2. Remove the demo (first feature only)

`Sources/Features/Notes` is the template's, not the app's. If the request **is** a notes
area, keep it and go on: the demo is the feature. Otherwise:

- `git rm -r Sources/Domains/Notes Sources/Domains/NotesLive Sources/Features/Notes
  Tests/Domains/NotesTests Tests/Features/NotesTests App/UITests/NotesUITests.swift`
- `Package.swift`: the five targets `Notes`, `NotesLive`, `NotesFeature`, `NotesTests`,
  `NotesFeatureTests`, and their names in the `AppModules` product and `AppRoot`'s
  `dependencies`.
- `App/<App>.xcodeproj/xcshareddata/xcschemes/<App>.xcscheme`: the two
  `<TestableReference>` blocks naming `NotesTests` and `NotesFeatureTests`.
- `AppModel`, `AppScenes`, `MainApp`: every line naming Notes — the model property and its
  `init` parameter, the view, the `NoteService` and the `noteService:` argument.
- Check: `git grep -n Notes -- '*.swift' Package.swift` names nothing,
  `swift package dump-package` loads and lists no Notes target, `make test` passes.

Until step 4 wires the new view, `AppScenes` shows
`Color.clear.frame(minWidth: 480, minHeight: 320)`.

### 3. Scaffold

`make feature NAME=<Name> CORES="<Core …>"`, the Cores being the targets the feature's code
uses (`Notes`, `Platform`). It refuses a name in use, a lowercase one and one whose logger
would be a Swift keyword: pick another name, do not write the files by hand. It writes the
files, declares both targets through `swift package add-target`, adds the test target to
the scheme, and prints the two lines that wire the feature in
([what it makes](references/scaffold-output.md)). A Core the feature needs later joins with
`swift package add-target-dependency <Core> <Name>Feature`.

`add-target` appends the blocks after the test targets, and SwiftPM reads no order into the
list: leave them there or move them beside the other features.

### 4. Fill it in

Add the printed lines, each file importing `<Name>Feature`: the model in `AppModel`, the
view in `AppScenes`. Then model logic in the model, layout in the view, every user-facing
string in `Text("…", bundle: .module)` and the feature's `Localizable.xcstrings`.

A feature never depends on another feature, and never on a `Live`: a service's protocol and
mock live in a Core, its live implementation in the matching `Live`, which
`App/Application/MainApp.swift` builds and hands to `AppModel`.

### 5. Translate and verify

For each locale in `REQUIRED_LOCALES` (`App/Configs/Identity.xcconfig`) except `en`, give
every string a value and set its `state` to `translated`. Then `make ci`, and show the user
the renders in `.build/renders/<Name>ViewRenderTests/`. A failing check and its fix:
[scaffold output and fixes](references/scaffold-output.md).

## Changes

| File | Change |
| --- | --- |
| `Sources/Features/<Name>/`, `Tests/Features/<Name>Tests/` | created by `make feature` |
| `Package.swift`, the scheme | both targets and `AppRoot`'s dependency |
| `AppRoot/AppModel.swift`, `AppRoot/AppScenes.swift` | the two printed lines |
| `Sources/Features/Notes/` and its tests | removed, first feature only |
| `App/Configs/App.entitlements`, `App/Configs/App.xcconfig` | only for a capability ([recipe](../add-capability/SKILL.md)) |

## The user's part

- Pick the area's name when the request does not name it.
- Approve the plan, and look at the renders of the new view before it ships.

## Done when

- `make ci` exits 0, and the user has seen the renders.

## Never

- Add files or settings to `App/<App>.xcodeproj` for a feature: the package carries it.
- Make one feature depend on another, or a feature depend on a `Live` target.
- Pass a model through `.environment`: pass it through `init`.
- Leave a scaffolded string untranslated, or delete it from the catalog, to pass lint.
