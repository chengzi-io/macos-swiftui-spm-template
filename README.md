# macOS SwiftUI SPM Template

[![CI](https://github.com/chengzi-io/macos-swiftui-spm-template/actions/workflows/ci.yml/badge.svg)](https://github.com/chengzi-io/macos-swiftui-spm-template/actions/workflows/ci.yml)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)
![Xcode 26](https://img.shields.io/badge/Xcode-26-147EFB?logo=xcode&logoColor=white)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

A macOS SwiftUI app template for building with coding agents. All code lives in a
Swift package, a thin Xcode project builds and signs it, `make` is the one entry point,
and a merged release PR becomes a DMG that installed copies update to through Sparkle.

```text
PR → make ci → squash merge → release PR → draft release: DMG, appcast → published → Sparkle updates
```

## ✨ What you get

| | |
| --- | --- |
| **Layout** | All code in the package at the root: `AppRoot`, a target per feature area, domains and `Platform` split into `Core` (protocols, mocks) and `Live`. A thin `App/<App>.xcodeproj` links one product of it, with every setting in `App/Configs/*.xcconfig`. [Why](docs/ARCHITECTURE.md) |
| **Rules for agents** | [AGENTS.md](AGENTS.md) (Claude Code reads it through `CLAUDE.md`). Swift 6 mode, MainActor by default in UI targets, warnings as errors, `make lint` rules against old APIs and layer-breaking imports. |
| **Tests** | Swift Testing unit tests in seconds, view snapshots in light and dark that a reviewer approves with a label, XCUITests on GitHub CI. |
| **Releases** | release-please versions and `CHANGELOG.md`; Developer ID signing and notarization, or ad-hoc until you have one; a draft release until the DMG and the appcast are checked; Sparkle 2 updates, EdDSA-signed. |
| **App basics** | App Sandbox, English and Simplified Chinese string catalogs, privacy manifest, an Icon Composer icon (Liquid Glass on macOS 26), an accent color that follows the user's. |
| **Skills** | `app-icon` makes the icon. On request: `dmg` designs the DMG window, `mac-app-store` adds an App Store build, `homebrew-cask` puts the app on Homebrew. |

## 🚀 Quick start

You need Xcode 26 (Swift 6.2), `jq` (ships with macOS 15+) and `brew install lefthook`.
init also needs `gh auth login`, or `--codeowner @you`. The app runs on macOS 14 or
later.

1. Click **Use this template** on GitHub and clone your new repository.
2. Make it your app:

   ```bash
   scripts/init.sh --name MyApp --bundle-id com.example.myapp   # optional: --display-name "My App"
   git add -A && git commit -m "chore: initialize MyApp from template"
   make setup       # check the toolchain, install git hooks
   make snapshots   # record the demo's view snapshots on this Mac; look at them, then commit
   make ci          # lint, unit tests, debug .app, launch smoke test
   make run         # build and launch the app
   ```

   init renames the package, project, targets and scheme, writes the identity into
   `App/Configs/Identity.xcconfig`, points releases at your repository, resets the
   version to `0.0.0`, and replaces this README with a page for your app's users. The
   header of [scripts/init.sh](scripts/init.sh) lists the options.

**With an agent:** open the repository in Claude Code, Codex or another agent that reads
`AGENTS.md`, and describe your app. It asks for the name and bundle identifier, runs
init, and finishes each change with `make ci`.

Then replace the Notes demo with your first feature ([AGENTS.md](AGENTS.md#add-a-feature)),
replace the icon (Icon Composer or the `app-icon` skill), and do the
[one-time release setup](docs/RELEASING.md#one-time-setup).

## ⚙️ Configuration and usage

**Identity** lives in `App/Configs/Identity.xcconfig` only:

| Key | What it sets |
| --- | --- |
| `APP_NAME`, `APP_DISPLAY_NAME`, `BUNDLE_ID` | Set by init. Before the first release, change them only with `scripts/rename.sh`. |
| `TEAM_ID` | Empty: ad-hoc signing, no notarization. Set: Developer ID signing and notarization. |
| `GITHUB_REPOSITORY` | `owner/repo` that serves the releases and Sparkle's appcast. |
| `APP_CATEGORY`, `COPYRIGHT` | The app's category (`LSApplicationCategoryType`) and its copyright line. |

**Commands** (`make help` lists all of them):

| Command | Does |
| --- | --- |
| `make run` | Build and launch the debug app, logs in the terminal |
| `make test` | Unit and snapshot tests, in seconds |
| `make ci` | The definition of done: lint, tests, debug `.app`, smoke test |
| `make snapshots` | Record new and changed view snapshots; review them before committing |
| `make test:ui` | XCUITests; they take over the mouse and keyboard |
| `make logs` | Stream the app's unified logs |

**Docs:**

| File | Covers | After init |
| --- | --- | --- |
| [AGENTS.md](AGENTS.md) | rules for agents, where code goes | kept |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | setup, commands, editors, how the app is built | kept |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | why the code is split this way, by example | kept |
| [docs/RELEASING.md](docs/RELEASING.md) | the release flow, one-time setup, recovery | kept |
| [docs/RECIPES.md](docs/RECIPES.md) | launch at login, networking, menu bar, shortcuts, AppKit bridges, crash reporting | kept |
| `docs/TEMPLATE-PLAN.md`, `docs/ACCEPTANCE.md` | the template's own plan and checks (Chinese) | removed |

## 🤝 Contributing

Changes to the template itself are welcome. Open a PR whose title is a Conventional
Commit (`fix(scripts): …`; CI checks it) and make sure `make ci` passes. A PR that
changes view snapshots needs the `snapshots-reviewed` label once someone has compared
the images. Details: [CONTRIBUTING.md](.github/CONTRIBUTING.md). Report security issues
privately: [SECURITY.md](.github/SECURITY.md).

## License

[MIT](LICENSE)
