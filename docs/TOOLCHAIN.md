# Toolchain

Which Xcode, Swift and macOS versions this repository builds with, and how to change
them. For people and agents.

## Versions

| What | Version | Set in |
| --- | --- | --- |
| Xcode | 26.2, the same as CI | `.xcode-version` (CI, the release workflow and `make doctor` read it) |
| CI runner | GitHub `macos-26` | `.github/workflows/ci.yml`, `release.yml` |
| Swift compiler | 6.2, the one in Xcode 26.2 | follows Xcode |
| Swift language mode | 6 | `swift-tools-version: 6.2` (`Package.swift`, `App/Package.swift`); `SWIFT_VERSION = 6.0` (`App/Configs/Project.xcconfig`) |
| Deployment target | macOS 14 | `platforms` in `Package.swift`; `MACOSX_DEPLOYMENT_TARGET` in `Project.xcconfig` |
| Warnings | errors | `.treatAllWarnings(as: .error)` in `Package.swift`; `SWIFT_TREAT_WARNINGS_AS_ERRORS` in `Project.xcconfig` |

"Swift 6.2" names the compiler and the manifest format; the code is written in the
Swift 6 language mode. `make versions` prints the macOS, the selected Xcode and
`.xcode-version`; `make doctor` warns when the local Xcode differs (in CI it fails).
`make lint` fails when the two deployment targets disagree.

## Rules

- Use Xcode 26.2 only. Don't use Swift 6.3+ or Xcode 27 APIs, flags or settings, because
  CI builds with 26.2 and would fail.
- Don't raise `swift-tools-version`, because it changes the manifest API and the
  defaults every target builds with.
- Edit `App/Application/AppIcon.icon` only with Icon Composer from Xcode 26, because a
  newer Icon Composer writes keys this Xcode ignores without a word.
- Upgrade in two PRs, never one: first `.xcode-version`, then `swift-tools-version`.
- Change both deployment targets in one commit, and drop the `#available` checks that
  become dead.

## Upgrade Xcode

1. Check that GitHub's `macos-26` image has the new Xcode: CI fails with
   "is not installed on this runner" otherwise.
2. Change `.xcode-version` only; install and select the same Xcode locally.
3. `make ci`; fix new warnings. Open the PR (`build: use Xcode 26.x`).

## Upgrade swift-tools-version

1. In a later PR, change the first line of `Package.swift` and `App/Package.swift`.
2. Turn any new upcoming features on in `Package.swift`'s `common` settings deliberately.
3. `make ci`. Open the PR (`build: swift-tools-version 6.x`).

## Xcode MCP (mcpbridge)

On macOS 26+ with Xcode 26.3+ and the project open in Xcode, `xcrun mcpbridge` lets an
agent build, run tests, render previews and search Apple's documentation through Xcode.
That is newer than the pin, so `make doctor` warns; CI is still the judge. It does not
launch on macOS 15, where the make targets do all of that but previews.

## Why CI runs on macos-26

GitHub's `macos-15` image (15.7.9) crashes Xcode 26 while compiling the Icon Composer
icon (`AppIcon.icon`); macOS 15.7.2 with Xcode 26.2 compiles it fine locally. So CI and
the release workflow run on `macos-26`, while macOS 15 stays fine for local work.
