#!/usr/bin/env bash
# Renders an Icon Composer .icon the ways people will see it, on two sheets:
#   .build/app-icon/<name>-check.png  macOS 26 in all six appearances (ictool, Icon
#       Composer's own renderer), 32 pt (the Finder list and menus), and this Mac's
#       Finder icon: on macOS 14 and 15 that is the flattened image actool bakes.
#   .build/app-icon/<name>-dock.png   this Mac's icon between installed apps, at 128 pt
#       and 32 pt.
# Fails on property names this Xcode ignores (lint-icon.swift) and on anything actool
# rejects or warns about, as the app build does.
# Runs from anywhere inside the project; paths are relative to its root.
#   check-icon.sh [path.icon] [app ...]    default apps: Safari, Notes, Photos, App Store
set -euo pipefail

die() {
    echo "error: $*" >&2
    exit 1
}

here=$(cd "$(dirname "$0")" && pwd)
cd "$(git rev-parse --show-toplevel)"
icon=${1:-App/AppIcon.icon}
[[ -f $icon/icon.json ]] || die "no icon.json in $icon"
if [[ $# -gt 1 ]]; then
    shift
    apps=("$@")
else
    apps=(/Applications/Safari.app /System/Applications/Notes.app /System/Applications/Photos.app "/System/Applications/App Store.app")
fi
for app in "${apps[@]}"; do
    [[ -d $app ]] || die "no app at $app"
done
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
[[ -x $ictool ]] || die "no ictool at $ictool; it ships with Icon Composer in Xcode 26"

# actool's ibtoold daemon resolves relative paths against its own working directory.
icon="$(cd "$icon" && pwd)"
name=$(basename "$icon" .icon)
xcrun swift "$here/lint-icon.swift" "$icon/icon.json"
out="$PWD/.build/app-icon"
renders="$out/$name"
rm -rf "$renders"
mkdir -p "$renders"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# A new bundle path per run, so the system icon cache cannot answer with an old icon.
preview="$tmp/Preview.app"
mkdir -p "$preview/Contents/MacOS" "$preview/Contents/Resources"
# Without a launchable executable Finder badges the icon as "cannot open".
cp /usr/bin/true "$preview/Contents/MacOS/Preview"
xcrun actool "$icon" --compile "$preview/Contents/Resources" --platform macosx \
    --minimum-deployment-target 14.0 --app-icon "$name" \
    --output-partial-info-plist "$tmp/icon.plist" --errors --warnings \
    --output-format human-readable-text >"$tmp/actool.log" 2>&1 || {
    cat "$tmp/actool.log" >&2
    die "actool rejected $icon"
}
# A layer whose image is missing is only a warning; actool exits 0 without the icon.
if grep -q 'warning:' "$tmp/actool.log"; then
    cat "$tmp/actool.log" >&2
    die "actool warned about $icon"
fi
plist="$preview/Contents/Info.plist"
plutil -create xml1 "$plist"
plutil -insert CFBundlePackageType -string APPL "$plist"
plutil -insert CFBundleExecutable -string Preview "$plist"
plutil -insert CFBundleIdentifier -string "app-icon.preview.$RANDOM$RANDOM" "$plist"
/usr/libexec/PlistBuddy -c "Merge $tmp/icon.plist" "$plist" >/dev/null

# ictool renders without validating; actool above has.
render() { # rendition, points, out.png
    "$ictool" "$icon" --export-image --output-file "$3" --platform macOS --rendition "$1" \
        --width "$2" --height "$2" --scale 2 >/dev/null
}
check=()
for rendition in Default Dark TintedLight TintedDark ClearLight ClearDark; do
    render "$rendition" 128 "$renders/$rendition.png"
    backdrop=light
    [[ $rendition == *Dark ]] && backdrop=dark
    check+=("$rendition|$renders/$rendition.png|$backdrop")
done
render Default 32 "$renders/32-Default.png"
render Dark 32 "$renders/32-Dark.png"
render TintedDark 32 "$renders/32-TintedDark.png"
xcrun swift "$here/render-icon.swift" "$preview" "$renders/finder.png" 128
check+=(
    "32 pt|$renders/32-Default.png|light"
    "32 pt, Dark|$renders/32-Dark.png|dark"
    "32 pt, TintedDark|$renders/32-TintedDark.png|dark"
    "this Mac|$renders/finder.png|light"
)
xcrun swift "$here/sheet.swift" "$out/$name-check.png" 6 280 "${check[@]}"

# The Dock row: the icon in the middle, as this Mac draws every icon in it.
xcrun swift "$here/render-icon.swift" "$preview" "$renders/dock-128.png" 128
xcrun swift "$here/render-icon.swift" "$preview" "$renders/dock-32.png" 32
large=() small=()
middle=$((${#apps[@]} / 2))
for i in "${!apps[@]}"; do
    if [[ $i -eq $middle ]]; then
        large+=("$name|$renders/dock-128.png|light")
        small+=("$name|$renders/dock-32.png|light")
    fi
    label=$(basename "${apps[$i]}" .app)
    xcrun swift "$here/render-icon.swift" "${apps[$i]}" "$renders/app-$i-128.png" 128
    xcrun swift "$here/render-icon.swift" "${apps[$i]}" "$renders/app-$i-32.png" 32
    large+=("$label|$renders/app-$i-128.png|light")
    small+=("$label|$renders/app-$i-32.png|light")
done
columns=${#large[@]}
xcrun swift "$here/sheet.swift" "$out/$name-dock.png" "$columns" 200 "${large[@]}" "${small[@]}"

echo "$out/$name-check.png"
echo "$out/$name-dock.png"
