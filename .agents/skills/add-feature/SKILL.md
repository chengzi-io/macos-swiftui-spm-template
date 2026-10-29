---
name: add-feature
description: Add a feature to this app - a new area the user works in, as a <Name>Feature target with its model, view, strings, render tests and scheme entry - and wire it into AppRoot. Use when the user asks for a new screen, window, panel or area of the app, or for a service a feature needs (network, files, a system API).
---

# Add feature

Adds one `<Name>Feature` target end to end, ending with `make ci` green.
`scripts/scaffold.sh` writes the files and the scheme entry; the `Package.swift`
blocks and the wiring are printed for you to paste, so they stay a reviewed edit.

`<skill>` is this skill's directory, `.agents/skills/add-feature`; run its script from
anywhere inside the project. `<App>` is `APP_NAME` in `App/Configs/Identity.xcconfig`.

## New target or not

| The user wants | Do |
| --- | --- |
| An area they work in, with its own data (a library, an inspector) | a new feature: this skill |
| Another screen of an area that exists (a detail view of Notes) | add it to that feature's folder and model; no new target |
| Work outside the process (network, files, a system API) | a service, step 4; a feature uses it |
| Something every Mac app has (updates, login item) | `Platform`, not a feature |

A feature never depends on another feature; only `AppRoot` puts features together.
`Sources/Features/Notes/` is the pattern to copy.

## What the scaffold makes

| File | Holds |
| --- | --- |
| `Sources/Features/<Name>/<Name>Model.swift` | `@Observable` model; the screens' state and the state they share |
| `Sources/Features/<Name>/<Name>View.swift` | the view, taking its model through `init`, and a `#Preview` |
| `Sources/Features/<Name>/Log.swift` | `Log.<name>`, the module's `Logger` |
| `Sources/Features/<Name>/Resources/Localizable.xcstrings` | the view's strings; one `new` entry per `REQUIRED_LOCALES` locale |
| `Tests/Features/<Name>Tests/<Name>ViewRenderTests.swift` | renders the view light and dark into `.build/renders/` |
| `App/<App>.xcodeproj/xcshareddata/xcschemes/<App>.xcscheme` | gains a `<Name>FeatureTests` `TestableReference` |

## Procedure

1. **Name it.** `<Name>` is the area, capitalized, without `Feature` (`Library` makes
   `LibraryFeature`). Agree on it with the user if the request does not say.
2. **Scaffold.** `<skill>/scripts/scaffold.sh <Name>`. It refuses a name in use, a
   lowercase one and one whose logger would be a Swift keyword; pick another name, do
   not create the files by hand. It prints three `Package.swift` blocks.
3. **Declare it in `Package.swift`.** Paste the blocks it printed:
   - the `<Name>Feature` target after the other features, with the Cores it uses in
     `dependencies:` and `swiftSettings: ui`;
   - the `<Name>FeatureTests` test target after the other feature tests, depending on
     the feature, the Cores its tests use and `RenderSupport`, as `NotesFeatureTests`
     does;
   - `"<Name>Feature"` in `AppRoot`'s `dependencies`.

   `make lint` fails while the scheme and `Package.swift` disagree on test targets, and
   `swift test` fails on an import of a target that is not declared.
4. **Services.** Work outside the process gets a service: the protocol and its mock in
   `Platform/Core/` or a domain's `Core/`, the live implementation in the matching
   `Live/` ([recipe: networking](../macos-recipes/references/networking.md)).
   `App/Application/MainApp.swift` builds the live one, and the mock under
   `UI_TESTING=1`, and passes it through `AppModel`. A new domain's two targets join
   the `AppModules` product in `Package.swift`; the Xcode project does not change.
5. **Wire it.** `AppModel` owns `<Name>Model`; `AppScenes` shows `<Name>View` (in an
   existing window, a new `Window` or `WindowGroup`, or `Settings`). A new screen later
   changes the feature's model, not `AppModel`.
6. **Build the feature.** Model logic in the model, layout in the view. Every
   user-facing string goes in `Text("…", bundle: .module)` and the feature's
   `Localizable.xcstrings`.
7. **Translate.** For each locale in `REQUIRED_LOCALES`
   (`App/Configs/Identity.xcconfig`) except `en`, give every string a value and set its
   `state` to `translated`. `make lint` fails on a `new` or missing one.
8. **Test.** In `Tests/Features/<Name>Tests/`: the model's logic with the Cores' mocks
   passed through `init`, and a render test per state worth seeing. Look at the PNGs in
   `.build/renders/<Name>ViewRenderTests/`. A flow worth guarding end to end gets an
   XCUITest in `App/UITests/`.
9. **Capabilities.** Network, files, camera and the like: add the entitlement to
   `App/Configs/App.entitlements` and its usage description as
   `INFOPLIST_KEY_NS…UsageDescription` in `App/Configs/App.xcconfig`.
10. **Verify.** `make ci`. Show the user the renders of the new view.

## If something fails

| Failure | Fix |
| --- | --- |
| `make lint`: `<Name>FeatureTests is not in the Test action` | the scheme lacks the entry: copy the `NotesFeatureTests` `TestableReference` in it and change its three names |
| `make lint`: `has no <locale> translation` | step 7 |
| `make lint`: `depends on <X>Feature` | a feature imports another; move the shared part into a domain's Core |
| `swift test`: `no such module` or an explicit-import error | the target's `dependencies` in `Package.swift` lack that module |

## Never

- Add files or settings to `App/<App>.xcodeproj` for a feature: the package carries it.
- Make one feature depend on another, or a feature depend on a `Live` target.
- Pass a model through `.environment`: pass it through `init`.
- Leave a scaffolded string untranslated or delete it from the catalog to pass lint.
