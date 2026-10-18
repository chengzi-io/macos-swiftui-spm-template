#!/usr/bin/env bash
# Builds $APP_NAME.app from the Swift package.
#   debug   → .build/app/Debug/$APP_NAME.app, ad-hoc signed, debugger can attach
#   release → dist/$APP_NAME.app, universal, hardened runtime, Developer ID or ad-hoc
# Prints the .app path on stdout.
#
# `swift build` output is not shippable: it copies .xcassets/.xcstrings raw and its
# Bundle.module looks outside Contents/Resources. xcodebuild compiles resources and
# generates an accessor that reads Bundle.main.resourceURL.

source "$(dirname "$0")/common.sh"

config=${1:-}
case "$config" in
    debug)
        xc_config=Debug
        app=$DEBUG_APP
        build_args=(-destination "platform=macOS,arch=$(uname -m)")
        ;;
    release)
        xc_config=Release
        app=$RELEASE_APP
        build_args=(-destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
        ;;
    *) die "usage: build-app.sh debug|release" ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

min_macos=$(swift package dump-package | jq -r '.platforms[] | select(.platformName == "macos") | .version')
[[ -n "$min_macos" ]] || die "Package.swift declares no macOS platform"

log "xcodebuild $xc_config"
xcodebuild build -quiet -scheme App -configuration "$xc_config" -derivedDataPath .build/xcode "${build_args[@]}"
products=".build/xcode/Build/Products/$xc_config"

log "assemble $app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
ditto "$products/App" "$app/Contents/MacOS/$APP_NAME"
shopt -s nullglob
for bundle in "$products"/*.bundle; do
    ditto "$bundle" "$app/Contents/Resources/$(basename "$bundle")"
done
frameworks=("$products"/PackageFrameworks/*.framework)
for framework in ${frameworks[@]+"${frameworks[@]}"}; do
    ditto "$framework" "$app/Contents/Frameworks/$(basename "$framework")"
done
shopt -u nullglob

log "compile Bundle/Assets.xcassets"
xcrun actool Bundle/Assets.xcassets \
    --compile "$app/Contents/Resources" \
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

log "write Info.plist ($VERSION build $BUILD_NUMBER)"
plist="$app/Contents/Info.plist"
cp Bundle/Info.plist "$plist"
set_string() { plutil -replace "$1" -string "$2" "$plist"; }
set_string CFBundleExecutable "$APP_NAME"
set_string CFBundleIdentifier "$BUNDLE_ID"
set_string CFBundleName "$APP_NAME"
set_string CFBundleDisplayName "$APP_DISPLAY_NAME"
set_string CFBundleShortVersionString "$VERSION"
set_string CFBundleVersion "$BUILD_NUMBER"
set_string LSMinimumSystemVersion "$min_macos"
set_string LSApplicationCategoryType "$APP_CATEGORY"
set_string NSHumanReadableCopyright "$COPYRIGHT"
/usr/libexec/PlistBuddy -c "Merge $tmp/assets.plist" "$plist" >/dev/null
plutil -lint -s "$plist"

if [[ $config == debug ]]; then
    identity="-"
    entitlements="$tmp/debug.entitlements"
    cp Bundle/App.entitlements "$entitlements"
    /usr/libexec/PlistBuddy -c "Add :com.apple.security.get-task-allow bool true" "$entitlements"
    sign_args=(--force --sign -)
else
    identity=$(signing_identity)
    entitlements=Bundle/App.entitlements
    sign_args=(--force --options runtime --sign "$identity")
    [[ $identity == "-" ]] || sign_args+=(--timestamp)
fi

log "codesign (identity: $identity)"
# Inside out, no --deep: nested code keeps its own entitlements.
shopt -s nullglob
for framework in "$app"/Contents/Frameworks/*.framework; do
    for nested in "$framework"/Versions/Current/XPCServices/*.xpc "$framework"/Versions/Current/*.app \
        "$framework"/Versions/Current/Autoupdate; do
        if [[ -e $nested ]]; then
            codesign "${sign_args[@]}" --preserve-metadata=entitlements "$nested"
        fi
    done
    codesign "${sign_args[@]}" "$framework"
done
shopt -u nullglob
codesign "${sign_args[@]}" --entitlements "$entitlements" "$app"
codesign --verify --deep --strict "$app"

echo "$app"
