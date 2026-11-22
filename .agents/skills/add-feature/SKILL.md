---
name: add-feature
description: Add a feature to this app - a new area the user works in, as a <Name>Feature target with its model, view, strings, render tests and scheme entry - and wire it into AppRoot. Use when the user asks for a new screen, window, panel or area of the app, or for a service a feature needs (network, files, a system API).
---

# Add feature

One `<Name>Feature` target end to end, ending with `make ci` green. Say what will change,
then run the scaffold; `App/App.xcodeproj` needs no edit.

## The scaffold

    make feature NAME=<Name> CORES="<Core …>"

Every argument is checked, so pass the shape it wants on the first call:

| Argument | Shape |
| --- | --- |
| `<Name>` | the area: a capital letter, then letters or digits, without `Feature` (`Library` makes `LibraryFeature`) |
| `CORES` | the domain targets the feature's code uses (`Notes`, `Platform`), each the same shape; optional |

It refuses a name whose logger (`Log.<name>`) would be a Swift keyword, and one already in
`Sources/Features/`, `Package.swift` or the scheme. It writes the files, declares both
targets and adds the test target to the scheme, then prints the two lines that wire the
feature in.

## Before the scaffold: which target at all

- A feature is an area the user works in, with data of its own. Another screen of an
  existing area goes in that area's folder and model, with no new target.
- Work outside the process is a service: [recipe](../add-capability/references/networking.md).
  Something every Mac app has (updates, login item) belongs in `Platform`.
- Where the screen goes — an existing window, a new `Window` or `WindowGroup`, or
  `Settings` — decides the `AppScenes` line.

## First feature: remove the demo

`Sources/Features/Notes` is the template's, not the app's. If the request is not a notes
area:

- `git rm -r Sources/Domains/Notes Sources/Domains/NotesLive Sources/Features/Notes
  Tests/Domains/NotesTests Tests/Features/NotesTests App/UITests/NotesUITests.swift`
- `Package.swift`: the five targets `Notes`, `NotesLive`, `NotesFeature`, `NotesTests`,
  `NotesFeatureTests`, and their names in the `AppModules` product and `AppRoot`'s
  `dependencies`.
- `App/App.xcodeproj/xcshareddata/xcschemes/App.xcscheme`: the two `<TestableReference>`
  blocks naming `NotesTests` and `NotesFeatureTests`.
- `AppModel`, `AppScenes`, `MainApp`: every line naming Notes — the model property and its
  `init` parameter, the view, the `NoteService` and the `noteService:` argument.
- Check: `git grep -n Notes -- '*.swift' Package.swift` names nothing,
  `swift package dump-package` lists no Notes target, `make test` passes.

Until the view is wired, `AppScenes` can show
`Color.clear.frame(minWidth: 480, minHeight: 320)`.

## After the scaffold

- Add the two printed lines, each file importing `<Name>Feature`: the model in `AppModel`,
  the view in `AppScenes`.
- `add-target` appends its blocks after the test targets, and SwiftPM reads no order into
  the list: leave them there or move them beside the other features.
- `make ci`, then show the user the renders in `.build/renders/<Name>ViewRenderTests/`.
  A failing check and its fix: [what fails after the scaffold](references/scaffold-output.md).

## Never

- Add files or settings to `App/App.xcodeproj` for a feature: the package carries it.
