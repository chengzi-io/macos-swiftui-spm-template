#!/usr/bin/env bash
# Builds a DMG with the Configs/DMG design through the project's scripts/make-dmg.sh,
# opens it in Finder and screenshots the window to .build/dmg/dmg.png. The terminal
# needs Screen Recording permission. Runs from anywhere inside the project.
#   preview-dmg.sh [app]    default: the debug app from `make app`
set -euo pipefail

die() {
    echo "error: $*" >&2
    exit 1
}

here=$(cd "$(dirname "$0")" && pwd)
cd "$(git rev-parse --show-toplevel)"
APP_NAME=$(sed -nE 's/^APP_NAME[[:space:]]*=[[:space:]]*//p' Configs/Identity.xcconfig)
[[ -n $APP_NAME ]] || die "no APP_NAME in Configs/Identity.xcconfig"
grep -q dmgbuild scripts/make-dmg.sh || die "scripts/make-dmg.sh is the plain one; wire dmgbuild in first"

app=${1:-.build/xcode/Build/Products/Debug/$APP_NAME.app}
[[ -d $app ]] || die "no app at $app; run make app"
dmg=.build/dmg/preview.dmg
out=.build/dmg/dmg.png

scripts/make-dmg.sh "$app" "$dmg"
mount=$(hdiutil attach -noverify "$dmg" | awk -F '\t' '/\/Volumes\// { print $NF }')
[[ -n $mount ]] || die "cannot mount $dmg"
trap 'hdiutil detach -quiet "$mount" || echo "error: cannot detach $mount" >&2' EXIT

open "$mount"
id=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
    id=$(xcrun swift "$here/window-id.swift" "$(pgrep -x Finder)" "$(basename "$mount")")
    [[ -n $id ]] && break
    sleep 1
done
[[ -n $id ]] || die "no Finder window for $mount (Screen Recording permission?)"
# Under Stage Manager a window of a background app sits tilted in the side strip, and
# that is what the screenshot would show.
open -a Finder
# Finder draws the background a moment after the window appears.
sleep 2
screencapture -x -o -l "$id" "$out"
echo "$out"
