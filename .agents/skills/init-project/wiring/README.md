# {{DISPLAY_NAME}}

[![Latest release](https://img.shields.io/github/v/release/{{REPO}})](https://github.com/{{REPO}}/releases/latest)
![macOS {{MIN_MACOS}}+](https://img.shields.io/badge/macOS-{{MIN_MACOS}}%2B-000000?logo=apple)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

_What {{DISPLAY_NAME}} does and for whom, in one sentence._

<!-- Replace the line above and add a screenshot. This page is for people who use the
     app; developer docs live in docs/. -->

## Install

Download the DMG from the [latest release](https://github.com/{{REPO}}/releases/latest),
open it and drag {{NAME}} to Applications. {{DISPLAY_NAME}} runs on macOS {{MIN_MACOS}} or later.

<!-- Delete this paragraph once TEAM_ID is set in App/Configs/Identity.xcconfig: apps
     signed with a Developer ID open without it. -->
macOS blocks the first launch because the app is not notarized yet: open System
Settings → Privacy & Security and click **Open Anyway**, once.

## Update

{{DISPLAY_NAME}} updates itself: choose **Check for Updates…** in the app menu, or turn on
**Automatically check for updates** in Settings.

## Feedback

[Report a bug](https://github.com/{{REPO}}/issues/new/choose). Report security issues
privately, as [SECURITY.md](.github/SECURITY.md) describes.

## Development

| Doc | Covers |
| --- | --- |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | the daily loop, commands, editors |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | why the code is split this way |
| [docs/RELEASING.md](docs/RELEASING.md) | how releases ship |

## License

[MIT](LICENSE)
