---
name: mac-app-store
description: Add a Mac App Store build to this app - a signed .pkg for App Store Connect, either beside the Sparkle and Developer ID release or instead of it. Wires the build, the scripts, the Xcode project and the code in on first use.
disable-model-invocation: true
---

# Mac App Store

The project ships outside the App Store: a DMG on GitHub Releases that Sparkle keeps
up to date. This skill adds an App Store build. The App Store updates the app itself,
so the App Store build carries no Sparkle: not linked, no `SU…` keys in `Info.plist`,
no Sparkle entitlements.

The build, the signing and the Xcode project are spelled out below: a mistake there
passes `make ci` and fails only in App Store Connect. The app's code is not. By the
time an app adds the App Store, its settings, menus and tests are its own, so for those
this skill says what must be true and how to find the places; read the code you find
and change it to fit. `make ci`, the AppStore build and the checks in step 5 tell you
when it is done.

## What this skill expects from the project

It is written for apps made from macos-swiftui-spm-template, once its init has run:

- `<App>` is the app's name. `App/<App>.xcodeproj` has the `<App>` target: its code is
  the buildable folder `App/Application/`, its settings `App/Configs/App.xcconfig`,
  `Info.plist` and `App.entitlements`. All other code is the package at the repository
  root (`Package.swift`, `Sources/`); the `<App>` target links one of its products,
  `AppModules`, which lists every module `App/Application/` imports.
- Updates go through an `UpdaterService` protocol in a Core target
  (`grep -rln 'protocol UpdaterService' Sources` finds it; `Sources/Domains/Platform/` in
  the template), and the one file that imports Sparkle implements it.
  `App/Application/MainApp.swift` builds the updater (a mock under `UI_TESTING=1`), and
  the app hands it down from there to every view that shows an update control.
- `scripts/build-app.sh debug|release` archives with xcodebuild and re-signs;
  `scripts/common.sh` exports `App/Configs/Identity.xcconfig` (`TEAM_ID`, `BUNDLE_ID`) and
  defines `die`, `log` and `find_identity`.
- `App/Configs/App.entitlements` turns the App Sandbox on, which the App Store requires.

If one of these does not hold, tell the user what differs before changing anything.

`<skill>` below is this skill's directory, for example `.agents/skills/mac-app-store`.
`<skill>/wiring/xcodeproj.py add-app-store-target` makes the one change this skill needs
in `App/<App>.xcodeproj`; never edit `project.pbxproj` by hand. It refuses, changing
nothing, when the project is not shaped as it expects.

Nothing here has reached App Store Connect: both channels were built, signed and
packaged with a stand-in identity (a placeholder `TEAM_ID` and ad-hoc signing in a
throwaway copy; without certificates `build-app.sh mas` stops at `TEAM_ID`, then at the
identity). Tell the user that the first real submission is its acceptance test.

## 1. Pick the channel

Ask the user, unless they already said:

| Channel | What changes |
| --- | --- |
| Both | The Developer ID release stays. A second app target, `AppStore`, builds the same app from `App/Application/` without Sparkle |
| App Store only | Sparkle and the GitHub DMG release go; the `<App>` target is the App Store app |

Then do step 2, and 3a or 3b.

## 2. Add the App Store build

1. `<skill>/wiring/build-app.sh` is the template's `scripts/build-app.sh` with a `mas`
   configuration. `diff scripts/build-app.sh <skill>/wiring/build-app.sh`: when every
   difference is a `mas` part, copy it over; otherwise the project changed its script,
   so add the `mas` parts to it. Then `cp <skill>/wiring/release-mas.sh scripts/`.
2. In `scripts/common.sh`, let `find_identity` take a policy; installer certificates
   are only listed under `basic`. Its comment, its `local` line and its
   `security find-identity` line become these; the rest of the function stays:

   ```bash
   # Prints the SHA-1 of the first valid identity for TEAM_ID whose name matches the
   # extended regex. Policy: codesigning (default) or basic (installer certificates).
   find_identity() {
       local pattern=$1 policy=${2:-codesigning}
       security find-identity -v -p "$policy" |
   ```

3. Makefile, in the Release section after the `release` target:

   ```make
   .PHONY: release-mas
   release-mas: ## Mac App Store .pkg in dist/mas/ (needs TEAM_ID, MAS_PROVISIONING_PROFILE)
   	scripts/release-mas.sh

   .PHONY: upload-mas
   upload-mas: ## Build the App Store .pkg and upload it to App Store Connect
   	scripts/release-mas.sh upload
   ```

4. In `docs/RELEASING.md`, replace the `## Mac App Store (optional)` section, which only
   points to this skill, with `<skill>/wiring/releasing.md`. Its first paragraph names
   the target for each channel; keep only the clause of the channel you picked (Both:
   the `AppStore` target).

## 3a. Both: an AppStore target without Sparkle

1. Move Sparkle into its own target, so the App Store build can still link the other
   live services. `grep -rln '^import Sparkle' Sources` names the file that wraps it;
   `git mv` it into a `SparkleUpdater/` folder beside the `PlatformLive/` folder it
   left (`Sources/Domains/SparkleUpdater/` in the template). In `Package.swift`, add the target
   (its dependency is the Core target that declares `UpdaterService`), take the Sparkle
   dependency off the target the file left, add `SparkleUpdater` to the `AppModules`
   product, and add the product the AppStore target links, `AppModules` without
   `SparkleUpdater`:

   ```swift
           .target(
               name: "SparkleUpdater",
               dependencies: ["Platform", .product(name: "Sparkle", package: "Sparkle")],
               path: "Sources/Domains/SparkleUpdater",
               swiftSettings: common
           ),
   ```

   ```swift
           // The AppStore target's product: AppModules without SparkleUpdater.
           .library(name: "AppStoreModules", targets: [/* AppModules' targets but SparkleUpdater */]),
   ```

   A target needs sources: one left without any goes, with its directory, its place in
   both products and every dependency on it, imports included. In the template
   `PlatformLive` holds nothing else, so it goes and `MainApp` imports `SparkleUpdater`
   in its place. `lint-rules.sh` reads every target's path from `swift package
   dump-package`, so the new folder is covered on its own; only the Live side is picked
   by target name, and `SparkleUpdater` has no `Live` suffix: add it to that case
   (`*Live|SparkleUpdater)`), or the check that keeps system frameworks in Live
   rejects its `import Sparkle`.

2. The App Store build has no updater. When you are done:

   - `App/Application/MainApp.swift` builds none under `APP_STORE`, and imports
     `SparkleUpdater` only outside it, after its other imports:

     ```swift
     #if !APP_STORE
         import SparkleUpdater
     #endif
     ```

     ```swift
     /// The App Store build has no updater: the App Store updates the app.
     private func makeUpdater(uiTesting: Bool) -> (any UpdaterService)? {
         #if APP_STORE
             return nil
         #else
             return uiTesting ? MockUpdaterService() : LiveUpdaterService()
         #endif
     }
     ```

     Call it where `MainApp` built the updater, with `uiTesting: true` where it builds
     the mocks.
   - Every property and parameter that carries the updater from there to the views that
     use it takes `(any UpdaterService)?`. Document one of them with `/// Nil in the App
     Store build: the App Store updates the app.`
     `grep -rn 'any UpdaterService' Sources App/Application` lists them, and those views
     too.
   - The views that use the updater keep a non-optional one, and are built only inside
     an `if let`: a menu item, a toggle, a button.
   - A settings pane left with nothing to set once its update controls go is gone from
     the App Store build, not shown empty; a version number alone does not keep it, as
     the About window shows the version. Whatever lists the panes (tabs, a sidebar, a
     search over them) leaves it out, code that opens a pane by name cannot open it,
     and a stored "last pane" that names it opens on the first pane left (map it when
     you read it). Settings left with one tab shows that pane alone, without the tabs;
     a sidebar window left with one pane is the user's call: ask. Settings left with no
     pane at all is not in the App Store build: no Settings window, no Settings… menu
     item. A scene body takes no `if` before macOS 15 (the compiler can crash on one),
     and the package cannot see `APP_STORE`: move the `Settings` scene into a `Scene`
     type of its own in the package, and list it in `MainApp`'s body inside
     `#if !APP_STORE`.
   - The Developer ID build behaves as before, and its tests pass unchanged: `swift
     test` builds without `APP_STORE`. Where a type decides what the App Store build
     shows (which panes it lists), test it with a nil updater too.

   Tell the user which controls the App Store build hides.

3. The App Store target's settings:

   ```bash
   cp <skill>/wiring/AppStore.xcconfig App/Configs/
   cp App/Configs/Info.plist App/Configs/AppStore-Info.plist
   cp App/Configs/App.entitlements App/Configs/AppStore.entitlements
   ```

   `AppStore.xcconfig` includes `App.xcconfig` and switches to the other two files and
   the `APP_STORE` compilation condition. The copies keep whatever the project added
   since init; take out what only Sparkle uses:

   - from `AppStore-Info.plist`, every `SU…` key;
   - from `AppStore.entitlements`, the mach-lookup exception's names that end in
     `-spks` and `-spki` (the whole key, and its comment, when no other name is left);
   - from `AppStore.entitlements`, `com.apple.security.network.client` too, unless the
     app makes network requests of its own (`grep -rln 'URLSession\|NWConnection'
     Sources App` finds them): the template has it for Sparkle.

   `plutil -lint` both.

4. The project, from the repository root:

   ```bash
   python3 <skill>/wiring/xcodeproj.py add-app-store-target AppStoreModules
   ```

   The `<App>` target keeps linking `AppModules`. The AppStore target compiles the same
   `App/Application/` folder, so there is one `@main`; `APP_STORE`
   tells the two builds apart. The script also writes the shared `AppStore` scheme,
   which `build-app.sh mas` archives. Both targets build `<App>.app` with the same
   bundle identifier, so they share a sandbox container and defaults, and in Xcode's
   own DerivedData the last one built replaces the other.

5. In `Sources/AGENTS.md` and `App/AGENTS.md`, where they describe the layout, the
   products and the dependencies, add the `AppStore` target, `SparkleUpdater` and
   `AppStoreModules`: a module added to `AppModules` goes in `AppStoreModules` too,
   unless it uses Sparkle. Where they say which target holds Sparkle, it is now
   `SparkleUpdater`; a target that went is gone from them too
   (`grep -rn PlatformLive Sources/AGENTS.md App/AGENTS.md docs .agents/skills/macos-recipes` in the template; `docs/ARCHITECTURE.md`
   describes an example app, so it stays). Say that
   `AppStore-Info.plist` and `AppStore.entitlements` are `Info.plist` and
   `App.entitlements` without Sparkle: a key added to one goes in the other too. In
   `.agents/skills/macos-recipes/references/`, code that passes `model.updater` on
   (`grep -rn updater .agents/skills/macos-recipes`) takes it as optional now, and builds its control inside `if let`.

6. `make fmt`, then `make ci`. `xcodebuild -list -project App/<App>.xcodeproj` lists the
   `AppStore` target and scheme. `make ci` builds only the `<App>` scheme, so compile the
   `APP_STORE` path too:
   `xcodebuild build -project App/<App>.xcodeproj -scheme AppStore -configuration Debug -derivedDataPath .build/xcode-appstore`.

Beyond that, the Developer ID release, Sparkle and their docs stay as they are.

## 3b. App Store only: remove Sparkle and the DMG release

Every build is now the App Store app; step 3a does not apply. When you are done,
nothing of Sparkle, the DMG, notarization, the appcast or the Developer ID release is
left, and every script still runs. Remove:

- From `scripts/build-app.sh`, the `release` configuration and what only it used: the
  script archives `$APP_TARGET` and signs it for the App Store, with no `case` left
  that has a single branch, and the signing loop loses Sparkle's helper (`Autoupdate`).
  Its header comment and usage follow.
- Sparkle from the code. The package in `Package.swift`, the file that imports it,
  `UpdaterService` and its mock; every property, parameter and argument that carried
  the updater; every control that used it; the tests and string catalog entries of what
  you removed. Settings panes follow step 3a.2: a pane left with nothing to set goes,
  and so do the tabs around a single pane. A target left without sources goes with its
  place in `AppModules` and every dependency on it, and a string catalog left empty
  with its target's `resources:`. In the template this removes `Platform` and
  `PlatformLive`, which hold only the updater, and the whole Settings feature (its
  target, tests and `Settings` scene), whose one pane was Updates.
  `grep -rni 'sparkle\|updater' Sources Tests App` finds what is left.
- `App/Configs/Info.plist` and `App/Configs/App.entitlements`: what only Sparkle uses,
  as step 3a.3 lists it.
- In `Package.swift`, `AppModules` lists only the modules `App/Application/` still
  imports (`grep -h '^ *import' App/Application/*.swift`). Both `Package.resolved`
  files (at the root and in
  `App/<App>.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`) drop the Sparkle pin
  on the next build; commit them.
- `scripts/common.sh`: what only the Developer ID release used (in the template
  `RELEASES_URL`, `ARCHIVE`, `RELEASE_APP`, `SPARKLE_BIN`, `sparkle_public_key`,
  `set_sparkle_public_key` and `signing_identity`).
- `scripts/lint-rules.sh`: `Sparkle` in its import checks, and any check on a folder
  that no longer exists.
- Scripts that only the Developer ID release used (in the template `appcast.sh`,
  `verify-appcast.swift`, `release.sh`, `package-dmg.sh`,
  `make-dmg.sh`, `verify-dmg.sh`, `notarize.sh`, `publish-github.sh`, `ci-keychain.sh`),
  their Makefile targets, and the note on the Release section's header about CI running
  `make release`.
- A Homebrew cask, if the `homebrew-cask` skill added one: Homebrew installs the DMG,
  so `scripts/update-cask.sh`, its job in `release.yml` and its keys in
  `App/Configs/Identity.xcconfig` go too.
- `.github/workflows/release.yml`: the `publish` job, and the release-please job's
  outputs that only fed it. release-please stays for versions and `CHANGELOG.md`; in
  `.github/release-please-config.json` drop `draft` and `force-tag-creation`, which
  only existed so the publish job could fill a draft.
- The `release-setup` skill: its step 3 and `scripts/sparkle-keys.sh`, its Sparkle and
  Developer ID lines in `scripts/check.sh`, and `references/developer-id.md`; step 4
  and step 5 now point to the App Store section of `docs/RELEASING.md`.
- `.agents/skills/release-setup/scripts/github-setup.sh`: the `release` environment
  stays, since it holds release-please's App key; drop the publish job from what the script says the
  environment is for, and the secrets only the publish job used
  (`SPARKLE_ED_PRIVATE_KEY`, `DEVELOPER_ID_P12_*`, `NOTARY_API_*`) from its notes.
- `App/Configs/Identity.xcconfig`: `GITHUB_REPOSITORY` once nothing reads it, and the
  repository in `App/AGENTS.md`'s list of what the file holds; the `TEAM_ID` comment now
  says App Store builds need it.
- `scripts/doctor.sh`: check for the Apple Distribution identity instead of Developer
  ID Application, and let its messages say what App Store builds need.
- The `dmg` and `homebrew-cask` skills, which build on the DMG release: their folders in
  `.agents/skills/` and their links in `.claude/skills/`.

Then rewrite the docs around the App Store. A passage that assumes the Developer ID
release is rewritten, not only cut: crash reports (Apple sends an App Store app's to
Xcode's Organizer), a dSYM upload that ran in the publish job, a runner chosen for a
release workflow that no longer builds. In `docs/RELEASING.md` keep the version rules
(without what Sparkle compares), the `## Setup` pointer to the `release-setup` skill
(its steps 1 and 2 still set up the repository and the GitHub App release-please needs)
and the Mac App Store section from step 2, trimmed to the App Store target alone
(`make release-mas` archives `<App>`); drop the release diagrams, draft releases, the
Sparkle key, Developer ID, recovery, crash symbolication, Homebrew and beta sections.
In `README.md` the install section points to the App Store, and an update section, if
there is one, goes: the App Store updates the app. In `AGENTS.md`, `Sources/AGENTS.md`,
`App/AGENTS.md`, `docs/DEVELOPMENT.md`, `docs/ARCHITECTURE.md` and the macos-recipes references,
drop Sparkle, the updater service, the DMG, notarization, the appcast, the publish job,
the `dmg` and `homebrew-cask` skills and any settings pane that went. A target or
folder that went (`Platform`, a Settings feature) is described as one to create when
first needed, and a recipe that puts a control in Settings starts by adding the
Settings feature. This finds what is left; read each hit, and keep only those about
building with Xcode (`dwarf-with-dsym`) or about the App Store:

```bash
grep -rni 'sparkle\|appcast\|notariz\|SUPublicEDKey\|RELEASES_URL\|updater\|CheckForUpdates\|Autoupdate\|DMG\|dSYM\|Developer ID\|homebrew\|publish job\|RELEASING.md, 4\|GITHUB_REPOSITORY\|`make release`' \
    --exclude-dir=.build --exclude-dir=.git --exclude-dir=.agents .
```

`make fmt`, then `make ci`. `make ci` builds Debug only, so compile the Release
configuration that `release-mas` archives too:
`xcodebuild build -project App/<App>.xcodeproj -scheme <App> -configuration Release -derivedDataPath .build/xcode-release`.
Its app has no `Contents/Frameworks/Sparkle.framework` and no `SU…` key in
`Info.plist`.

## 4. What the user sets up

1. Certificates **Apple Distribution** and **Mac Installer Distribution** in the login
   keychain; `TEAM_ID` in `App/Configs/Identity.xcconfig`.
2. An App ID for the bundle identifier and a **Mac App Store** provisioning profile.
3. The app record in App Store Connect, including its export compliance answer.
4. An App Store Connect API key (`.p8`, key ID, issuer ID) for `make upload-mas`.

## 5. Check and finish

1. `make ci`; for Both, also `make release` when the Sparkle key is set up.
2. With the user's identities and profile:
   `MAS_PROVISIONING_PROFILE=<path> make release-mas`. In `dist/mas/<App>.app` check
   that there is no `Contents/Frameworks/Sparkle.framework`, no `SU…` key in
   `Info.plist`, and a `Contents/embedded.provisionprofile`; that
   `codesign -d --entitlements - <app>` shows `com.apple.application-identifier` and no
   `mach-lookup` exception.
3. Commit, for example `feat(mas): add a mac app store build`.
