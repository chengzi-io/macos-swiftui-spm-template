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

## What this skill expects from the project

It is written for apps made from macos-swiftui-spm-template, once its init has run:

- `<App>` is the app's name. `App/<App>.xcodeproj` has the `<App>` target: its code is
  the buildable folder `App/Application/`, its settings `App/Configs/App.xcconfig`. All
  other code is the package at the repository root (`Package.swift`, `Sources/`).
- `Sources/Services/UpdaterService.swift` declares `UpdaterService` and
  `MockUpdaterService`; `Sources/ServicesLive/LiveUpdaterService.swift` wraps Sparkle.
  `App/Application/MainApp.swift` builds the updater, `AppModel.updater` holds it, and
  `Sources/AppRoot/AppScenes.swift` shows `CheckForUpdatesButton` and hands the updater
  to `SettingsView`.
- `scripts/build-app.sh debug|release` archives with xcodebuild and re-signs;
  `scripts/common.sh` exports `App/Configs/Identity.xcconfig` (`TEAM_ID`, `BUNDLE_ID`) and
  defines `die`, `log`, `find_identity` and `signing_identity`.
- `App/Configs/App.entitlements` turns the App Sandbox on, which the App Store requires.

`<skill>` below is this skill's directory, for example `.agents/skills/mac-app-store`.
`<skill>/wiring/xcodeproj.py` makes every change to `App/<App>.xcodeproj`; never edit
`project.pbxproj` by hand. It refuses, changing nothing, when the project is not shaped
as it expects.

Nothing here has reached App Store Connect: both channels were built, signed and
packaged with a stand-in identity. Tell the user that the first real submission is its
acceptance test.

## 1. Pick the channel

Ask the user, unless they already said:

| Channel | What changes |
| --- | --- |
| Both | The Developer ID release stays. A second app target, `AppStore`, builds the same app from `App/Application/` without Sparkle |
| App Store only | Sparkle and the GitHub DMG release go; the `<App>` target is the App Store app |

Then do step 2, and 3a or 3b.

## 2. Add the App Store build

1. `cp <skill>/wiring/release-mas.sh <skill>/wiring/build-app.sh scripts/`. The new
   `build-app.sh` is the template's with a `mas` configuration; if the project changed
   its `scripts/build-app.sh` since init, merge the `mas` parts in instead.
2. In `scripts/common.sh`, let `find_identity` take a policy; installer certificates
   are only listed under `basic`:

   ```bash
   # Prints the SHA-1 of the first valid identity for TEAM_ID whose name matches the
   # extended regex. Policy: codesigning (default) or basic (installer certificates).
   find_identity() {
       local pattern=$1 policy=${2:-codesigning}
       security find-identity -v -p "$policy" |
   ```

3. Makefile, in the Release section:

   ```make
   .PHONY: release-mas
   release-mas: ## Mac App Store .pkg in dist/mas/ (needs TEAM_ID, MAS_PROVISIONING_PROFILE)
   	scripts/release-mas.sh

   .PHONY: upload-mas
   upload-mas: ## Build the App Store .pkg and upload it to App Store Connect
   	scripts/release-mas.sh upload
   ```

4. In `docs/RELEASING.md`, replace the `## Mac App Store (optional)` section, which only
   points to this skill, with `<skill>/wiring/releasing.md`.

## 3a. Both: an AppStore target without Sparkle

1. Move Sparkle into its own target, so the App Store target can still link the other
   live services:

   ```bash
   mkdir Sources/SparkleUpdater
   git mv Sources/ServicesLive/LiveUpdaterService.swift Sources/SparkleUpdater/
   ```

   In `Package.swift`, add the product and the target, and take the
   Sparkle dependency off `ServicesLive`:

   ```swift
           .library(name: "SparkleUpdater", targets: ["SparkleUpdater"]),
   ```

   ```swift
           .target(
               name: "SparkleUpdater",
               dependencies: ["Services", .product(name: "Sparkle", package: "Sparkle")],
               swiftSettings: common
           ),
   ```

   A target needs sources: when `ServicesLive` has none left (a fresh template), delete
   its directory, target and product. In `scripts/lint-rules.sh`, the `import SwiftUI`
   check lists `Sources/ServicesLive`: add `Sources/SparkleUpdater`, and drop
   `ServicesLive` if you deleted it.

2. The App Store build gets no updater, so the updater becomes optional.
   `AppRoot/AppModel.swift`:

   ```swift
       /// Nil in the App Store build: the App Store updates the app.
       public let updater: (any UpdaterService)?

       public init(updater: (any UpdaterService)?) {
   ```

   `AppRoot/AppScenes.swift`, inside the `CommandGroup`:

   ```swift
                   if let updater = model.updater {
                       CheckForUpdatesButton(updater: updater)
                   }
   ```

   `Features/Settings/SettingsView.swift`: the property and the initializer take
   `(any UpdaterService)?` (`/// Pass nil where the app does not update itself (the App
   Store build).`), and the toggle sits inside `if let updater { … }`. If that leaves
   the App Store build's Settings empty, tell the user.

   `App/Application/MainApp.swift`: import `SparkleUpdater` instead of `ServicesLive` (keep
   `ServicesLive` if it still exists), and build no updater for the App Store:

   ```swift
   #if !APP_STORE
       import SparkleUpdater
   #endif
   ```

   ```swift
   /// The App Store build has no updater: the App Store updates the app.
   private func makeUpdater() -> (any UpdaterService)? {
       #if APP_STORE
           return nil
       #else
           if ProcessInfo.processInfo.environment["UI_TESTING"] == "1" {
               return MockUpdaterService()
           }
           return LiveUpdaterService()
       #endif
   }
   ```

3. The App Store target's settings:

   ```bash
   cp <skill>/wiring/AppStore.xcconfig <skill>/wiring/AppStore-Info.plist <skill>/wiring/AppStore.entitlements App/Configs/
   ```

   `AppStore.xcconfig` includes `App.xcconfig` and switches to the other two files and
   the `APP_STORE` compilation condition. `AppStore-Info.plist` and
   `AppStore.entitlements` are `App/Configs/Info.plist` and `App/Configs/App.entitlements`
   without Sparkle's keys; carry over anything the project added to those since init.

4. The project, from the repository root:

   ```bash
   python3 <skill>/wiring/xcodeproj.py link <App> AppRoot Services SparkleUpdater
   python3 <skill>/wiring/xcodeproj.py add-app-store-target AppRoot Services
   ```

   Name the products `App/Application/MainApp.swift` imports, plus `ServicesLive` while it
   exists. The AppStore target compiles the same `App/Application/` folder, so there is one
   `@main`; `APP_STORE` tells the two builds apart. The script also writes the shared
   `AppStore` scheme, which `build-app.sh mas` archives.

5. In `AGENTS.md` and `docs/DEVELOPMENT.md`, where they describe the layout, add the
   `AppStore` target and `SparkleUpdater`.

6. `make fmt`, then `make ci`. `xcodebuild -list -project App/<App>.xcodeproj` lists the
   `AppStore` target and scheme.

The Developer ID release, Sparkle and their docs stay as they are.

## 3b. App Store only: remove Sparkle and the DMG release

Every build is now the App Store app. In `scripts/build-app.sh`, set `scheme=App` in the
`mas` branch, and drop the `release` configuration, its signing branch and its line in
the header comment and the usage. Then remove:

- Sparkle: the package in `Package.swift`,
  `ServicesLive/LiveUpdaterService.swift`, and `Services/UpdaterService.swift` (protocol
  and mock). A target left without sources (`ServicesLive` and `Services` in a fresh
  template) goes with its product and every dependency on it.
- The updater in the app: `AppModel.updater`, `makeUpdater` and its imports in
  `App/Application/MainApp.swift`, `AppRoot/CheckForUpdatesButton.swift` and the `.commands` in
  `AppScenes`, the toggle in `SettingsView`, and their entries in the string catalogs.
  A catalog left empty goes with its target's `resources:`. A Settings screen left
  empty (a fresh template) goes too: the `SettingsFeature` target and the `Settings`
  scene.
- `App/Configs/Info.plist`: `SUEnableInstallerLauncherService`, `SUFeedURL` and
  `SUPublicEDKey`. `App/Configs/App.entitlements`: the Sparkle mach-lookup exception.
- In the project, link only what `App/Application/MainApp.swift` imports (`AppRoot` in
  a fresh template): `python3 <skill>/wiring/xcodeproj.py link <App> AppRoot`. With no
  remote package left, Xcode deletes
  `App/<App>.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` and
  SwiftPM deletes `Package.resolved`; commit the deletions.
- `scripts/common.sh`: `RELEASES_URL`, `SPARKLE_PUBLIC_KEY` (it reads `SUPublicEDKey`,
  which is gone, and would fail every script), `ARCHIVE`, `RELEASE_APP`, `SPARKLE_BIN`,
  `set_sparkle_public_key` and `signing_identity`.
- `scripts/lint-rules.sh`: the checks on directories that no longer exist.
- Scripts that only the Developer ID release used: `appcast.sh`, `verify-appcast.swift`,
  `sparkle-keys.sh`, `release.sh`, `package-dmg.sh`, `make-dmg.sh`, `verify-dmg.sh`,
  `notarize.sh`, `publish-github.sh`, `ci-keychain.sh`; their Makefile targets
  (`release-app`, `release-dmg`, `appcast`, `release`, `sparkle-keys`) and the note on
  the Release section's header about CI running `make release`.
- A Homebrew cask, if the `homebrew-cask` skill added one: Homebrew installs the DMG,
  so `scripts/update-cask.sh`, its job in `release.yml` and its keys in
  `App/Configs/Identity.xcconfig` go too.
- `.github/workflows/release.yml`: the `publish` job. release-please stays for versions
  and `CHANGELOG.md`; in `.github/release-please-config.json` drop `draft` and
  `force-tag-creation`, which only existed so the publish job could fill a draft.
- `scripts/github-setup.sh`: the `release` environment, the closing note about its
  secrets, and the environment in the `github-setup` help line of the Makefile.
- `App/Configs/Identity.xcconfig`: `GITHUB_REPOSITORY` once nothing reads it; the
  `TEAM_ID` comment now says App Store builds need it.
- `scripts/doctor.sh`: check for the Apple Distribution identity instead of Developer
  ID Application.

Then rewrite the docs around the App Store: in `docs/RELEASING.md` keep the version
rules and the section from step 2, and drop the DMG, Sparkle, Developer ID, Homebrew,
recovery and beta sections; in `README.md` the install section points to the App
Store; in `AGENTS.md`, `docs/DEVELOPMENT.md` and `docs/RECIPES.md`, drop Sparkle, the
updater service, the DMG, notarization and the appcast. This finds what is left:

```bash
grep -rn 'Sparkle\|appcast\|notariz\|SPARKLE\|SUPublicEDKey\|RELEASES_URL\|UpdaterService\|DMG\|Developer ID\|release environment\|`make release`' \
    --exclude-dir=.build --exclude-dir=.git --exclude-dir=.agents .
```

`make fmt`, then `make ci`.

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
