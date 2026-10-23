#!/usr/bin/env bash
# Renders Configs/DMG/Background.swift into Configs/DMG/background.png and @2x. Runs from
# anywhere inside the project.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cd "$(git rev-parse --show-toplevel)"
[[ -f Configs/DMG/Background.swift ]] ||
    { echo "error: no Configs/DMG/Background.swift; copy the skill's templates/ there first" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
xcrun swiftc -swift-version 6 -parse-as-library \
    "$here/render-dmg-background.swift" Configs/DMG/Background.swift -o "$tmp/render"
"$tmp/render" Configs/DMG
echo Configs/DMG/background.png Configs/DMG/background@2x.png
