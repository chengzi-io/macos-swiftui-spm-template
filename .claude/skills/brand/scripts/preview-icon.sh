#!/usr/bin/env bash
# Renders an Icon Composer .icon as this Mac's Finder and Dock show it.
#   preview-icon.sh [path.icon] [out.png] [points]
# macOS 26 renders Liquid Glass; macOS 14 and 15 show the flattened images actool
# bakes into Assets.car for them.
set -euo pipefail

icon=${1:-Bundle/AppIcon.icon}
out=${2:-.build/brand/icon.png}
points=${3:-512}
[[ -f $icon/icon.json ]] || { echo "error: no icon.json in $icon" >&2; exit 1; }
# actool's ibtoold daemon resolves relative paths against its own working directory.
icon="$(cd "$(dirname "$icon")" && pwd)/$(basename "$icon")"
here=$(cd "$(dirname "$0")" && pwd)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# A new bundle path per run, so the system icon cache cannot answer with an old icon.
app="$tmp/Preview.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$(dirname "$out")"
# Without a launchable executable Finder badges the icon as "cannot open".
cp /usr/bin/true "$app/Contents/MacOS/Preview"

name=$(basename "$icon" .icon)
xcrun actool "$icon" --compile "$app/Contents/Resources" --platform macosx \
    --minimum-deployment-target 14.0 --app-icon "$name" \
    --output-partial-info-plist "$tmp/icon.plist" --errors --warnings \
    --output-format human-readable-text >"$tmp/actool.log" 2>&1 || {
    cat "$tmp/actool.log" >&2
    exit 1
}
if grep -q 'warning:' "$tmp/actool.log"; then
    grep 'warning:' "$tmp/actool.log" >&2
fi

plist="$app/Contents/Info.plist"
plutil -create xml1 "$plist"
plutil -insert CFBundlePackageType -string APPL "$plist"
plutil -insert CFBundleExecutable -string Preview "$plist"
plutil -insert CFBundleIdentifier -string "brand.preview.$RANDOM$RANDOM" "$plist"
/usr/libexec/PlistBuddy -c "Merge $tmp/icon.plist" "$plist" >/dev/null

xcrun swift "$here/render-icon.swift" "$app" "$out" "$points"
echo "$out"
