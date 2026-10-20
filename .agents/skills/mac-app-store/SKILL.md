---
name: mac-app-store
description: Add a Mac App Store build to this app - a signed .pkg for App Store Connect, either beside the Sparkle and Developer ID release or instead of it. Wires the build, the scripts and the code in on first use.
disable-model-invocation: true
---

# Mac App Store

The project ships outside the App Store: a DMG on GitHub Releases that Sparkle keeps
up to date. This skill adds an App Store build. The App Store updates the app itself,
so the App Store build carries no Sparkle.

## What this skill expects from the project

It is written for apps made from macos-swiftui-spm-template, once its init has run:

- `Package.swift` depends on Sparkle; `Sources/App/Updates.swift` wraps it,
  `Sources/App/MainApp.swift` adds the Check for Updates command and passes the update
  toggle to `Sources/AppCore/SettingsView.swift`.
- `scripts/build-app.sh debug|release` assembles and signs the `.app`;
  `scripts/common.sh` loads `Bundle/app.env` and defines `die`, `log` and
  `find_identity`.
- `Bundle/app.env` sets `TEAM_ID`; `Bundle/App.entitlements` turns the App Sandbox on,
  which the App Store requires.

`<skill>` below is this skill's directory, for example `.agents/skills/mac-app-store`.

Nothing here has reached App Store Connect: the build was checked up to signing with
a stand-in identity. Tell the user that the first real submission is its acceptance
test.

## 1. Pick the channel

Ask the user, unless they already said:

| Channel | What changes |
| --- | --- |
| Both | The Developer ID release stays. `APP_STORE=1` compiles Sparkle out of the App Store build only |
| App Store only | Sparkle and the GitHub DMG release go; every build is the App Store app |

Then do step 2, and 3a or 3b.

## 2. Add the App Store build

1. `cp <skill>/wiring/release-mas.sh scripts/release-mas.sh`
2. In `scripts/common.sh`, let `find_identity` take a policy; installer certificates
   are only listed under `basic`:

   ```bash
   # Prints the SHA-1 of the first valid identity for TEAM_ID whose name matches the
   # extended regex. Policy: codesigning (default) or basic (installer certificates).
   find_identity() {
       local pattern=$1 policy=${2:-codesigning}
       security find-identity -v -p "$policy" |
   ```

3. In `scripts/build-app.sh`, add the `mas` configuration to the header comment, the
   config `case` and the usage line:

   ```bash
   #   mas     → dist/mas/$APP_NAME.app, universal, no Sparkle, Apple Distribution signed;
   #             needs TEAM_ID and MAS_PROVISIONING_PROFILE
   ```

   ```bash
       mas)
           [[ -n ${TEAM_ID:-} ]] || die "App Store builds need TEAM_ID in Bundle/app.env"
           [[ -f ${MAS_PROVISIONING_PROFILE:-} ]] ||
               die "set MAS_PROVISIONING_PROFILE to the Mac App Store .provisionprofile"
           mas_identity=$(find_identity "Apple Distribution|3rd Party Mac Developer Application")
           [[ -n $mas_identity ]] || die "no Apple Distribution identity for team $TEAM_ID in the keychain"
           xc_config=Release
           app="dist/mas/$APP_NAME.app"
           derived_data=.build/xcode-mas
           build_args=(-destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
           ;;
       *) die "usage: build-app.sh debug|release|mas" ;;
   ```

   and the `mas` branch of the signing `case`:

   ```bash
       mas)
           identity=$mas_identity
           ditto "$MAS_PROVISIONING_PROFILE" "$app/Contents/embedded.provisionprofile"
           /usr/libexec/PlistBuddy \
               -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" \
               -c "Add :com.apple.developer.team-identifier string $TEAM_ID" \
               "$entitlements"
           sign_args=(--force --sign "$identity")
           ;;
   ```

4. Makefile, in the Release section:

   ```make
   .PHONY: release-mas
   release-mas: ## Mac App Store .pkg in dist/mas/ (needs TEAM_ID, MAS_PROVISIONING_PROFILE)
   	scripts/release-mas.sh

   .PHONY: upload-mas
   upload-mas: ## Build the App Store .pkg and upload it to App Store Connect
   	scripts/release-mas.sh upload
   ```

5. In `docs/RELEASING.md`, replace the `## Mac App Store (optional)` section, which only
   points to this skill, with `<skill>/wiring/releasing.md`.

## 3a. Both: compile Sparkle out of the App Store build

`release-mas.sh` builds with `APP_STORE=1`. Keep the Sparkle version the project
already pins.

- `Package.swift`:

  ```swift
  // `make release-mas` sets APP_STORE=1: the App Store updates the app, so Sparkle is left out.
  let appStore = Context.environment["APP_STORE"] == "1"
  ```

  before `let package`, then:

  ```swift
      dependencies: appStore
          ? []
          : [
              .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
          ],
  ```

  ```swift
              dependencies: ["AppCore"] + (appStore ? [] : [.product(name: "Sparkle", package: "Sparkle")]),
              swiftSettings: swiftSettings + (appStore ? [.define("APP_STORE")] : []),
  ```

- `Sources/App/Updates.swift`: the whole file inside `#if !APP_STORE` … `#endif`.
- `Sources/App/MainApp.swift`: `@StateObject private var updates` and the `.commands`
  modifier inside `#if !APP_STORE`; in `Settings`,

  ```swift
  #if APP_STORE
      SettingsView(automaticallyChecksForUpdates: nil)
  #else
      SettingsView(automaticallyChecksForUpdates: $updates.automaticallyChecksForUpdates)
  #endif
  ```

- `Sources/AppCore/SettingsView.swift`: the parameter becomes `Binding<Bool>?`
  (`/// Pass nil where the app does not update itself (App Store builds).`), and the
  toggle shows only `if let automaticallyChecksForUpdates`.
- `scripts/build-app.sh`: with `APP_STORE=1` SwiftPM drops Sparkle and would rewrite
  `Package.resolved`, so the `mas` build compiles a copy. Replace the `xcodebuild` call:

  ```bash
  source_dir=$ROOT
  if [[ $config == mas ]]; then
      # APP_STORE=1 drops Sparkle from Package.swift; resolving that in the repo would
      # rewrite Package.resolved, so build a copy.
      source_dir="$tmp/src"
      for path in Package.swift Package.resolved Sources Tests; do
          ditto "$path" "$source_dir/$path"
      done
      export APP_STORE=1
  fi

  log "xcodebuild $config"
  (cd "$source_dir" && xcodebuild build -quiet -scheme App -configuration "$xc_config" \
      -derivedDataPath "$ROOT/$derived_data" "${build_args[@]}")
  ```

The Developer ID release, Sparkle and their docs stay as they are.

## 3b. App Store only: remove Sparkle and the DMG release

Every build is now the App Store app, and the `mas` build compiles the repository as
it is. Remove:

- `Package.swift`: the Sparkle package and product, and the `linkerSettings` rpath
  (it exists for embedded frameworks). Run `swift package resolve`: with no
  dependencies SwiftPM deletes `Package.resolved`.
- Sparkle in the app: `Sources/App/Updates.swift`, `Sources/AppCore/Updates/`, the
  `updates` property and `.commands` in `MainApp.swift`, the toggle and its parameter
  in `SettingsView.swift` (call it as `SettingsView()`), and the "Check for Updates…"
  and "Automatically check for updates" entries in `Localizable.xcstrings`.
- `scripts/build-app.sh`: the `release` configuration and its signing branch, and the
  Sparkle block (`sparkle=…Sparkle.framework` through its `fi`). `scripts/common.sh`:
  `RELEASE_APP` and `signing_identity`.
- Scripts that only the Developer ID release used: `appcast.sh`, `verify-appcast.swift`,
  `sparkle-keys.sh`, `release.sh`, `package-dmg.sh`, `make-dmg.sh`, `verify-dmg.sh`,
  `notarize.sh`, `publish-github.sh`, `ci-keychain.sh`; their Makefile targets
  (`release-app`, `release-dmg`, `appcast`, `release`, `sparkle-keys`) and the note on
  the Release section's header about CI running `make release`.
- A Homebrew cask, if the `homebrew-cask` skill added one: Homebrew installs the DMG,
  so `scripts/update-cask.sh` and its job in `release.yml` go too.
- `.github/workflows/release.yml`: the `publish` job. release-please stays for versions
  and `CHANGELOG.md`; in `.github/release-please-config.json` drop `draft` and
  `force-tag-creation`, which only existed so the publish job could fill a draft.
- `scripts/github-setup.sh`: the `release` environment, the closing note about its
  secrets, and the environment in the `github-setup` help line of the Makefile.
- `Bundle/app.env`: `RELEASES_URL` and `SPARKLE_PUBLIC_KEY`; the `TEAM_ID` comment now
  says App Store builds need it.
- `scripts/doctor.sh`: check for the Apple Distribution identity instead of Developer
  ID Application.

Then rewrite the docs around the App Store: in `docs/RELEASING.md` keep the version
rules and the section from step 2, and drop the DMG, Sparkle, Developer ID, Homebrew,
recovery and beta sections; in `README.md` the install section points to the App
Store; in `AGENTS.md`, `docs/DEVELOPMENT.md` and `docs/RECIPES.md`, drop Sparkle, the
DMG, notarization and the appcast. This finds what is left:

```bash
grep -rn 'Sparkle\|appcast\|notariz\|SPARKLE\|RELEASES_URL\|DMG\|Developer ID\|release environment\|`make release`' \
    --exclude-dir=.build --exclude-dir=.git --exclude-dir=.agents .
```

## 4. What the user sets up

1. Certificates **Apple Distribution** and **Mac Installer Distribution** in the login
   keychain; `TEAM_ID` in `Bundle/app.env`.
2. An App ID for the bundle identifier and a **Mac App Store** provisioning profile.
3. The app record in App Store Connect.
4. An App Store Connect API key (`.p8`, key ID, issuer ID) for `make upload-mas`.

## 5. Check and finish

1. `make ci`; for Both, also `make release` when the Sparkle key is set up.
2. With the user's identities and profile:
   `MAS_PROVISIONING_PROFILE=<path> make release-mas`. In `dist/mas/<App>.app` check
   that there is no `Contents/Frameworks/Sparkle.framework` and no `SU…` key in
   `Info.plist`, that `codesign -d --entitlements - <app>` shows
   `com.apple.application-identifier`, and, for Both, that `git status` shows
   `Package.resolved` untouched.
3. Commit, for example `feat(mas): add a mac app store build`.
