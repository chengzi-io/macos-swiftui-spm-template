#!/usr/bin/env bash
# Compiles App/Assets.xcassets and App/AppIcon.icon with actool and fails on any
# warning. When a layer's image is missing, actool only warns, and Xcode's build
# passes with the icon from an earlier build still in the app.

source "$(dirname "$0")/common.sh"

min_macos=$(sed -nE 's/^MACOSX_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*//p' Configs/Project.xcconfig)
[[ -n $min_macos ]] || die "no MACOSX_DEPLOYMENT_TARGET in Configs/Project.xcconfig"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Absolute paths: actool hands the work to a long-lived ibtoold, which resolves relative
# paths against its own working directory, possibly another checkout.
xcrun actool "$ROOT/App/Assets.xcassets" "$ROOT/App/AppIcon.icon" \
    --compile "$tmp" \
    --platform macosx \
    --minimum-deployment-target "$min_macos" \
    --app-icon AppIcon \
    --accent-color AccentColor \
    --output-partial-info-plist "$tmp/assets.plist" \
    --errors --warnings \
    --output-format human-readable-text >"$tmp/actool.log" 2>&1 || {
    cat "$tmp/actool.log" >&2
    die "actool failed"
}
if grep -q 'warning:' "$tmp/actool.log"; then
    cat "$tmp/actool.log" >&2
    die "actool warned"
fi
