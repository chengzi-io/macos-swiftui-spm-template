# macOS SwiftUI app template, built for coding agents

[![CI](https://github.com/chengzi-io/macos-swiftui-spm-template/actions/workflows/ci.yml/badge.svg)](https://github.com/chengzi-io/macos-swiftui-spm-template/actions/workflows/ci.yml)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)
![Xcode 26.2](https://img.shields.io/badge/Xcode-26.2-147EFB?logo=xcode&logoColor=white)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Ship a native macOS app with the boring parts done and the structure enforced: `swift
test` runs unit and render tests in seconds without building the app; a new feature or
domain needs zero Xcode project edits; a feature cannot import a live service, so tests
and previews run on mocks; once you ship, merging a release PR publishes a DMG that
updates your users through Sparkle. One entry point — `make` — shared by people and agents.

## How it is organized

```mermaid
flowchart TB
    main["App/Application/MainApp.swift — @main<br/>the only code that builds the Live services"]
    root["Sources/AppRoot — AppModel, windows, Settings"]
    feature["Sources/Features/&lt;Name&gt; — a user area: its screens and model"]
    core["Sources/Domains/&lt;Name&gt; — protocol, types, mock"]
    live["Sources/Domains/&lt;Name&gt;Live — system APIs, network, files"]
    main --> root --> feature --> core
    main --> live --> core
```

One rule holds it together: a feature never imports a Live target — the build rejects
it — so every test and preview runs on mocks, and `swift test` builds no app, no Xcode.
Why each layer exists: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## For / not for

| For | Not for |
| --- | --- |
| a native macOS app, small to medium, built by one person or an agent | iOS, cross-platform, or a large team with its own conventions |

## What you get

| Mechanism | What it buys you |
| --- | --- |
| all code in one Swift package | `swift test` in seconds; any editor understands the project |
| a thin Xcode shell: buildable folders, settings in `App/Configs/*.xcconfig` | a feature or domain joins without touching `project.pbxproj` |
| `make lint` enforces the layering: services come in through `init`, mocks in tests | an agent cannot quietly wire a screen to the real system |
| every screen rendered light and dark by a render test | CI uploads the images; a broken layout is seen, not guessed |
| Swift 6 language mode, warnings as errors, lefthook, pinned toolchain | what compiles is clean; `make ci` is the same gate CI runs |
| release-please and Sparkle, added by the `setup-releases` skill when you ship | merging a release PR ships a DMG, appcast and changelog |
| nine skills ([`.agents/skills/`](.agents/skills)), entered by saying **next step** | the agent knows the big moves, in order: setup, features, the icon, the DMG, releases, signing, Homebrew |
| string catalogs enforced per `REQUIRED_LOCALES`, sandbox, privacy manifest, Icon Composer icon | the parts every App Store review asks for, done |

## Start

1. Click **Use this template** on GitHub and clone your new repository.
2. `make setup` — checks the toolchain and installs the git hooks.
3. Open it in your agent and say **next step**. It runs `make status`, tells you what
   comes next, what that changes and what you do yourself, and runs it once you agree.
   Say it again after each step.

The route it walks; the dashed steps are optional:

```mermaid
flowchart LR
    project["setup-project<br/>name, bundle id"] --> repo["push main<br/>make github-settings"]
    repo --> dev["everyday development<br/>add-feature, add-capability,<br/>design-app-icon, design-dmg-window"]
    dev --> releases["setup-releases<br/>pipeline, GitHub App, Sparkle key"]
    releases -.-> signing["setup-developer-id"]
    releases --> ship["each release<br/>merge the release PR"]
    ship -.-> brew["setup-homebrew"]
```

The first feature replaces the Notes demo. `make help` lists every command; `make run`
starts the app.

Day-to-day commands and editors: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Prerequisites

| Need | Why |
| --- | --- |
| A Mac with Xcode 26.2, the version CI uses | Swift 6.2 compiler (Swift 6 language mode); the app runs on macOS 14+ |
| `sudo xcodebuild -runFirstLaunch` | Xcode's first-launch tasks, once |
| `brew install lefthook gh`, then `gh auth login` | git hooks; GitHub for init and pull requests |
| A coding agent that reads `AGENTS.md` | Claude Code, Codex, Cursor or similar |

## Contributing

Changes to the template are welcome: [CONTRIBUTING.md](.github/CONTRIBUTING.md).
Report security issues privately: [SECURITY.md](.github/SECURITY.md).

## License

[MIT](LICENSE)
