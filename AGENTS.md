# AGENTS.md

A macOS SwiftUI app. All code lives in the Swift package at the repository root
(`Package.swift`, `Sources/`, `Tests/`); `App/<App>.xcodeproj` is a thin Xcode shell that
builds, signs and packages it, and `scripts/` ships it. `<App>` is the app's name
(`APP_NAME` in `App/Configs/Identity.xcconfig`): the package, project, app target and
scheme carry it. This file holds what every task needs; the rest is in the files below.

## Done means

| Command | When | Takes |
| --- | --- | --- |
| `make test` | after every change (unit and render tests) | seconds |
| `make ci` | before calling a task done: the definition of done, same as CI | minutes |
| `make run` | to launch the debug app; logs go to the terminal | a minute |
| `make fmt` | to format Swift sources (the pre-commit hook formats staged files) | seconds |
| `make test:ui` | only when the user asks: it takes over the mouse and keyboard | minutes |

CI also runs `make test:ui`, shellcheck and actionlint on every PR. `make help` lists
every target.

## Toolchain

Xcode 26.2 only (`.xcode-version`; CI uses the `macos-26` runner), Swift 6.2, macOS 14
target, warnings as errors. Never raise `swift-tools-version` or use Swift 6.3+ or Xcode
27 features: [docs/TOOLCHAIN.md](docs/TOOLCHAIN.md).

## Never

- Don't add build settings to `project.pbxproj`, because they belong in `App/Configs/*.xcconfig` (lint fails).
- Don't make a package target depend on a Live target, because only `MainApp` builds live services (lint fails).
- Don't delete, loosen or skip a test to turn it green, because the test is the spec; fix the code.
- Don't write `@unchecked Sendable` or `nonisolated(unsafe)`, because they hide the races Swift 6 catches.
- Don't silence a warning, because warnings are errors in the package and the app; fix it.
- Don't add a dependency, DI container, SwiftLint, Tuist or XcodeGen, because Sparkle is the one exception.
- Don't push, merge, tag or release without the user's go-ahead, because others see it at once.
- Don't skip the git hooks (`--no-verify`, `LEFTHOOK=0`), because CI runs the same checks; fix what they report.
- Don't commit certificates, `.p12`/`.p8` files or the Sparkle private key, because the repository may be public.
- Don't edit `version.txt`, `.release-please-manifest.json` or `CHANGELOG.md`, because release-please owns them.

## Before editing, read

Before changing files in a directory, read its `AGENTS.md` first: tools that start at
the root (Codex) load only this file, not the nested ones.

| Directory | Read | Covers |
| --- | --- | --- |
| `Sources/` | [Sources/AGENTS.md](Sources/AGENTS.md) | layers, where code goes, dependency direction, concurrency and DI, forbidden APIs |
| `Tests/` | [Tests/AGENTS.md](Tests/AGENTS.md) | Swift Testing, mocks, render tests, test discipline, UI tests |
| `App/` | [App/AGENTS.md](App/AGENTS.md) | the Xcode shell, xcconfigs and identity, `MainApp` as composition root, the icon |
| `scripts/` | [scripts/AGENTS.md](scripts/AGENTS.md) | bash conventions, `common.sh`, BSD tools, shellcheck |
| `.github/` | [.github/AGENTS.md](.github/AGENTS.md) | workflows, pinned actions, the Xcode version, actionlint |

## Skills

Skills live in `.agents/skills/`; `.claude/skills/` links to each one, so link a new
skill the same way. The last three change the build or the release: start them only
when the user names them.

| Skill | Use it to |
| --- | --- |
| [add-feature](.agents/skills/add-feature/SKILL.md) | add a screen, window or area as a `<Name>Feature` target, or a service it needs |
| [macos-recipes](.agents/skills/macos-recipes/SKILL.md) | add launch at login, networking, a menu bar item, a global shortcut, an AppKit bridge, crash reporting, Keychain, SwiftData or a privacy-manifest entry |
| [app-icon](.agents/skills/app-icon/SKILL.md) | make or replace the app icon (`App/Application/AppIcon.icon`) |
| [dmg](.agents/skills/dmg/SKILL.md) | design the DMG window |
| [mac-app-store](.agents/skills/mac-app-store/SKILL.md) | add a Mac App Store build |
| [homebrew-cask](.agents/skills/homebrew-cask/SKILL.md) | publish the app as a Homebrew cask |

## Docs

| File | What it covers | Reader |
| --- | --- | --- |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | why the app is layered this way | people; agents when needed |
| [docs/TOOLCHAIN.md](docs/TOOLCHAIN.md) | pinned versions, upgrades, mcpbridge, the CI runner | people and agents |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | the daily loop, editor setup, commands | people |
| [docs/RELEASING.md](docs/RELEASING.md) | running a release, recovery, crash symbolication | people |
| [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) | commit and PR titles, the PR flow | people and agents |

## Commits

Conventional Commits; the squash-merged PR title becomes the commit on `main`. One PR
does one thing and ends with `make ci` green. Details:
[.github/CONTRIBUTING.md](.github/CONTRIBUTING.md).
