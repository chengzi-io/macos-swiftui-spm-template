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
| **Tests** | Swift Testing unit tests in seconds, every screen rendered in light and dark for agents and reviewers to look at, XCUITests on GitHub CI. |
| **Releases** | release-please versions and `CHANGELOG.md`; Developer ID signing and notarization, or ad-hoc until you have one; a draft release until the DMG and the appcast are checked; Sparkle 2 updates, EdDSA-signed. |
| **App basics** | App Sandbox, English and Simplified Chinese string catalogs, privacy manifest, an Icon Composer icon (Liquid Glass on macOS 26), an accent color that follows the user's. |
| **Skills** | `app-icon` makes the icon. On request: `dmg` designs the DMG window, `mac-app-store` adds an App Store build, `homebrew-cask` puts the app on Homebrew. |

## 🚀 Quick start

You need Xcode 26 (Swift 6.2), `jq` (ships with macOS 15+) and `brew install lefthook`.
init also needs `gh auth login`, or your GitHub handle. The app runs on macOS 14 or
later.

1. Click **Use this template** on GitHub and clone your new repository.
2. Make it your app: open the repository in Claude Code, Codex or another agent that
   reads `AGENTS.md` and ask it to initialize the app. The
   [init-project skill](.agents/skills/init-project/SKILL.md) asks for the name, bundle
   identifier and the rest once, shows what will change, applies it and commits
   `chore: initialize MyApp from template`. Then:

   ```bash
   make setup       # check the toolchain, install git hooks
   make ci          # lint, unit tests, debug .app, launch smoke test
   make run         # build and launch the app
   ```

   init renames the package, project, targets and scheme, writes the identity into
   `App/Configs/Identity.xcconfig`, points releases at your repository, can remove
   the Notes demo, and replaces this README with a page for your app's users. Its
   scripts also run by hand: `.agents/skills/init-project/scripts/check.sh --help`.

Then replace the Notes demo with your first feature ([AGENTS.md](AGENTS.md#add-a-feature)),
replace the icon (Icon Composer or the `app-icon` skill), and do the
[one-time release setup](docs/RELEASING.md#one-time-setup).

## ⚙️ Configuration and usage

**Identity** lives in `App/Configs/Identity.xcconfig` only:

| Key | What it sets |
| --- | --- |
| `APP_NAME`, `APP_DISPLAY_NAME`, `BUNDLE_ID` | Set by init. A rename also renames the package, project, targets and scheme, and only before the first release. |
| `TEAM_ID` | Empty: ad-hoc signing, no notarization. Set: Developer ID signing and notarization. |
| `GITHUB_REPOSITORY` | `owner/repo` that serves the releases and Sparkle's appcast. |
| `APP_CATEGORY`, `COPYRIGHT` | The app's category (`LSApplicationCategoryType`) and its copyright line. |

**Commands** (`make help` lists all of them):

| Command | Does |
| --- | --- |
| `make run` | Build and launch the debug app, logs in the terminal |
| `make test` | Unit tests and view renders, in seconds |
| `make ci` | The definition of done: lint, tests, debug `.app`, smoke test |
| `make test:ui` | XCUITests; they take over the mouse and keyboard |
| `make logs` | Stream the app's unified logs |

**Docs:**

| File | Covers |
| --- | --- |
| [AGENTS.md](AGENTS.md) | rules for agents, where code goes |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | setup, commands, editors, how the app is built |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | why the code is split this way, by example |
| [docs/RELEASING.md](docs/RELEASING.md) | the release flow, one-time setup, recovery |
| [docs/RECIPES.md](docs/RECIPES.md) | launch at login, networking, menu bar, shortcuts, AppKit bridges, crash reporting |

## 🤝 Contributing

Changes to the template itself are welcome. Open a PR whose title is a Conventional
Commit (`fix(scripts): …`; CI checks it) and make sure `make ci` passes. Details:
[CONTRIBUTING.md](.github/CONTRIBUTING.md). Report security issues privately:
[SECURITY.md](.github/SECURITY.md).

## License

[MIT](LICENSE)
