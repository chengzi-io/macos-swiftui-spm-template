#!/usr/bin/env bash
# Renders Bundle/DMG/Background.swift into Bundle/DMG/background.png and @2x.
set -euo pipefail

cd "$(dirname "$0")/../../../.."
here=.agents/skills/dmg/scripts
[[ -f Bundle/DMG/Background.swift ]] ||
    { echo "error: no Bundle/DMG/Background.swift; copy .agents/skills/dmg/templates/ first" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
xcrun swiftc -swift-version 6 -parse-as-library \
    "$here/render-dmg-background.swift" Bundle/DMG/Background.swift -o "$tmp/render"
"$tmp/render" Bundle/DMG
echo Bundle/DMG/background.png Bundle/DMG/background@2x.png
