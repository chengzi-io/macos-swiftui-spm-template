# macos-swiftui-spm-template

<!-- template-only:start -->
AI-friendly macOS app template built on Swift Package Manager — pure `Package.swift`,
no `.xcodeproj`, predictable layout, and AGENTS.md conventions for LLM-assisted
development. Create a repository with **Use this template**, then follow
[Start a new app](#start-a-new-app).
<!-- template-only:end -->

## What you get

- A SwiftUI app in a Swift package: `App` (entry point, scenes, updater) and `AppCore`
  (views, models, services), tested with Swift Testing.
- Swift 6 language mode, MainActor by default, warnings as errors.
- `.app` packaging with no Xcode project: xcodebuild compiles the package, including
  asset and string catalogs; `scripts/build-app.sh` assembles, signs and verifies the
  bundle.
- App Sandbox; Developer ID signing, hardened runtime and notarization — or ad-hoc
  signing until you have a Developer ID.
- Sparkle 2 updates from GitHub Releases, EdDSA-signed.
- English and Simplified Chinese string catalog, privacy manifest, accent color, and an
  Icon Composer app icon: Liquid Glass on macOS 26, flattened images on macOS 14–15.
- Two agent skills in `.agents/skills` (linked from `.claude/skills`): `brand` writes a
  brand brief and icon layers for Icon Composer; `dmg`, started by you only (`/dmg` in
  Claude Code, `$dmg` in Codex), designs an optional DMG window.
- `make ci`: `swift format` lint, unit tests, debug `.app`, launch smoke test.
- GitHub: CI on macOS runners, PR title check, release-please versioning and
  CHANGELOG, a publish job that uploads DMG, dSYM, appcast and checksums, Dependabot.
  Optional Homebrew cask and Mac App Store package.

## Requirements

- Xcode 26 (Swift 6.2), selected with `xcode-select`
- [lefthook](https://lefthook.dev) for git hooks: `brew install lefthook`
- The app runs on macOS 14 or later

<!-- template-only:start -->
## Start a new app

After **Use this template** and cloning your repository:

```bash
scripts/init.sh --name MyApp --bundle-id com.example.myapp \
  --display-name "My App" --copyright "Jane Doe"
make setup   # check the toolchain, install git hooks
make run     # build and launch the debug app
```

`scripts/init.sh` writes the app identity into `Bundle/app.env`, points releases and
updates at your repository, resets the version to `0.0.0`, updates LICENSE, README,
CODEOWNERS and the issue templates, removes the template's own planning docs, and
finally deletes itself. Then replace the icon (open `Bundle/AppIcon.icon` in Icon
Composer, or have your agent run the brand skill) and the Greeter demo, and work through the one-time setup in
[docs/RELEASING.md](docs/RELEASING.md).

<!-- template-only:end -->

## Commands

| Command | What it does |
| --- | --- |
| `make setup` | Check the toolchain and install git hooks |
| `make doctor` | Check Xcode, tools and signing identity |
| `make run` | Build and launch the debug `.app`; logs in the terminal, `ARGS="…"` go to the app |
| `make app` | Build the debug `.app` (ad-hoc signed) into `.build/app/Debug/` |
| `make test` | Unit tests (`swift test`) |
| `make fmt` / `make lint` | Format / check formatting with `swift format` |
| `make smoke` | Launch-test the debug `.app` (or `APP=path`) |
| `make ci` | Everything CI runs; the definition of done |
| `make logs` | Stream the app's unified logs |
| `make release` | Universal, signed, notarized (with a Developer ID) DMG, dSYM, appcast in `dist/` |
| `make release-dry-run` | The release build and DMG checks without signing secrets; CI runs it on release PRs |
| `make sparkle-keys` | Create the Sparkle EdDSA key; write the public key to `Bundle/app.env` |
| `make github-setup` | Squash-only merges, branch protection, `release` environment |
| `make release-mas` / `make upload-mas` | Mac App Store `.pkg`, and its upload |

`make help` lists everything.

Try the Chinese UI with `make run ARGS="-AppleLanguages '(zh-Hans)'"`.

## Layout

```text
Package.swift              targets, platforms, Swift settings, Sparkle
Sources/App/               @main, scenes, commands, app delegate, updater
Sources/AppCore/           views, models, services, Localizable.xcstrings
Tests/AppCoreTests/        Swift Testing
Bundle/                    app.env, Info.plist, entitlements, privacy manifest, AppIcon.icon
scripts/                   build, sign, notarize, package, publish
.github/                   CI, PR title, release-please, Dependabot, templates
version.txt                current version, owned by release-please
```

## Editors

- Xcode: `xed .` opens `Package.swift`. Its Run button starts the bare executable,
  outside an `.app`: no bundle identifier, no sandbox, no Info.plist. Use it for quick
  UI checks and SwiftUI previews; for the real app run `make run` and attach the
  debugger (Debug › Attach to Process, or `lldb -n <AppName>`).
- VS Code / Cursor: the Swift extension (sourcekit-lsp) works on the package as is.

## Releases

release-please reads Conventional Commit PR titles on `main`, keeps a release PR with
the next version and CHANGELOG, and tags the release when that PR is merged. The
publish job then builds, signs, notarizes and uploads the DMG; Sparkle picks it up from
`releases/latest/download/appcast.xml`. One-time setup and details:
[docs/RELEASING.md](docs/RELEASING.md).

## License

[MIT](LICENSE)
