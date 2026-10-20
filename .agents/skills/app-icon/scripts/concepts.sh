#!/usr/bin/env bash
# Compares concept marks before any color: each SVG in the directory (a black mark on a
# transparent 1024 × 1024 canvas) goes on a plain white icon, rendered at 128 pt and at
# 32 pt side by side, three concepts to a row.
#   concepts.sh [dir]    default .build/app-icon/concepts → <dir>.png

source "$(dirname "$0")/../../../../scripts/common.sh"

here=.agents/skills/app-icon/scripts
dir=${1:-.build/app-icon/concepts}
dir=${dir%/}
svgs=()
for svg in "$dir"/*.svg; do
    [[ -f $svg ]] && svgs+=("$svg")
done
[[ ${#svgs[@]} -gt 0 ]] || die "no .svg in $dir"
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
[[ -x $ictool ]] || die "no ictool at $ictool; it ships with Icon Composer in Xcode 26"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
items=()
for svg in "${svgs[@]}"; do
    name=$(basename "$svg" .svg)
    icon="$tmp/$name.icon"
    mkdir -p "$icon/Assets"
    cp "$svg" "$icon/Assets/mark.svg"
    cat >"$icon/icon.json" <<'EOF'
{
  "fill" : { "solid" : "srgb:1.00000,1.00000,1.00000,1.00000" },
  "groups" : [ { "layers" : [ { "glass" : false, "image-name" : "mark.svg", "name" : "mark" } ] } ],
  "supported-platforms" : { "squares" : [ "macOS" ] }
}
EOF
    for points in 128 32; do
        "$ictool" "$icon" --export-image --output-file "$tmp/$name-$points.png" --platform macOS \
            --rendition Default --width "$points" --height "$points" --scale 2 >/dev/null
    done
    items+=("$name|$tmp/$name-128.png|light" "$name, 32 pt|$tmp/$name-32.png|light")
done

columns=$((${#items[@]} < 6 ? ${#items[@]} : 6))
xcrun swift "$here/sheet.swift" "$dir.png" "$columns" 280 "${items[@]}"
echo "$dir.png"
