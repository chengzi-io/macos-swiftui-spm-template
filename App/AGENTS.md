# App

The thin Xcode shell that builds, signs and packages the app; its code lives in `Sources/`.
Supplements the root [AGENTS.md](../AGENTS.md).

| Path | Holds |
|---|---|
| `<App>.xcodeproj` | targets `<App>` and `<App>UITests`; links one package product, `AppModules` |
| `Application/MainApp.swift` | `@main`, the composition root: the only code that builds Live services |
| `Application/` | the app delegate, `Log.swift`, `Assets.xcassets`, `AppIcon.icon`, `PrivacyInfo.xcprivacy`; no views |
| `Configs/Identity.xcconfig` | the app's identity: the only place to change it |
| `Configs/*.xcconfig`, `Info.plist`, `App.entitlements` | every build setting; Sparkle's keys; entitlements |
| `Package.swift` | empty: keeps `App/` out of the root package in Xcode |

## Identity.xcconfig

| Key | Affects |
|---|---|
| `APP_NAME`, `APP_DISPLAY_NAME`, `BUNDLE_ID` | the app; change only before the first release, since updates match the bundle id |
| `APP_CATEGORY`, `COPYRIGHT` | Info.plist |
| `TEAM_ID` | release signing and notarization only (`scripts/build-app.sh`); local builds stay ad-hoc |
| `GITHUB_REPOSITORY`, `REQUIRED_LOCALES` | release and appcast URLs; the translations `make lint` requires |

Setup writes every key; change them here only. `scripts/common.sh` reads them too, so keep
plain `KEY = value` lines: no quotes, no `$(...)`, no `//`.

## Rules

- `Application/` and `UITests/` are buildable folders, and new modules join the `AppModules` product in the root `Package.swift`: neither needs a project edit.
- `MainApp` builds the Live services, or the mocks under `UI_TESTING=1` in DEBUG builds only, and hands them to `AppModel`.
- A new capability: its entitlement in `Configs/App.entitlements`, its usage text as `INFOPLIST_KEY_NS…UsageDescription` in `Configs/App.xcconfig`.
- Edit `AppIcon.icon` only in Icon Composer from Xcode 26; check it with `make assets`.

## Never

| Do not | Because |
|---|---|
| put a build setting in `project.pbxproj` or edit it by hand | it overrides the xcconfig; `make lint` fails on any |
| pick a Team in Xcode's Signing & Capabilities panel | it writes `DEVELOPMENT_TEAM` into the project; set `TEAM_ID` instead |
| add the package with "Add Local…" | Xcode then builds it with `-suppress-warnings`, which breaks the build |
