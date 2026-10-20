#!/usr/bin/env bash
# Renders Bundle/DMG/Background.swift into Bundle/DMG/background.png and @2x. Runs from
# anywhere inside the project.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cd "$(git rev-parse --show-toplevel)"
[[ -f Bundle/DMG/Background.swift ]] ||
    { echo "error: no Bundle/DMG/Background.swift; copy the skill's templates/ there first" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
xcrun swiftc -swift-version 6 -parse-as-library \
    "$here/render-dmg-background.swift" Bundle/DMG/Background.swift -o "$tmp/render"
"$tmp/render" Bundle/DMG
echo Bundle/DMG/background.png Bundle/DMG/background@2x.png
