#!/usr/bin/env bash
# Builds $APP_NAME.app from the Swift package.
#   debug   → .build/app/Debug/$APP_NAME.app, ad-hoc signed, debugger can attach
#   release → dist/$APP_NAME.app, universal; Developer ID + hardened runtime, or ad-hoc
#   mas     → dist/mas/$APP_NAME.app, universal, no Sparkle, Apple Distribution signed;
#             needs TEAM_ID and MAS_PROVISIONING_PROFILE
# Prints the .app path on stdout.
#
# `swift build` output is not shippable: it copies .xcassets/.xcstrings raw and its
# Bundle.module looks outside Contents/Resources. xcodebuild compiles resources and
# generates an accessor that reads Bundle.main.resourceURL.

source "$(dirname "$0")/common.sh"

universal=(-destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
derived_data=.build/xcode
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
        build_args=("${universal[@]}")
        ;;
    mas)
        [[ -n ${TEAM_ID:-} ]] || die "App Store builds need TEAM_ID in Bundle/app.env"
        [[ -f ${MAS_PROVISIONING_PROFILE:-} ]] ||
            die "set MAS_PROVISIONING_PROFILE to the Mac App Store .provisionprofile"
        mas_identity=$(find_identity "Apple Distribution|3rd Party Mac Developer Application")
        [[ -n $mas_identity ]] || die "no Apple Distribution identity for team $TEAM_ID in the keychain"
        xc_config=Release
        app="dist/mas/$APP_NAME.app"
        derived_data=.build/xcode-mas
        build_args=("${universal[@]}")
        ;;
    *) die "usage: build-app.sh debug|release|mas" ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

min_macos=$(swift package dump-package | jq -r '.platforms[] | select(.platformName == "macos") | .version')
[[ -n "$min_macos" ]] || die "Package.swift declares no macOS platform"

source_dir=$ROOT
if [[ $config == mas ]]; then
    # APP_STORE=1 drops Sparkle from Package.swift; resolving that in the repo would
    # rewrite Package.resolved, so build a copy.
    source_dir="$tmp/src"
    for path in Package.swift Package.resolved Sources Tests; do
        ditto "$path" "$source_dir/$path"
    done
    export APP_STORE=1
fi

log "xcodebuild $config"
(cd "$source_dir" && xcodebuild build -quiet -scheme App -configuration "$xc_config" \
    -derivedDataPath "$ROOT/$derived_data" "${build_args[@]}")
products="$derived_data/Build/Products/$xc_config"

log "assemble $app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
ditto "$products/App" "$app/Contents/MacOS/$APP_NAME"
shopt -s nullglob
for bundle in "$products"/*.bundle; do
    ditto "$bundle" "$app/Contents/Resources/$(basename "$bundle")"
done
frameworks=("$products"/*.framework "$products"/PackageFrameworks/*.framework)
for framework in ${frameworks[@]+"${frameworks[@]}"}; do
    ditto "$framework" "$app/Contents/Frameworks/$(basename "$framework")"
done
shopt -u nullglob
ditto Bundle/PrivacyInfo.xcprivacy "$app/Contents/Resources/PrivacyInfo.xcprivacy"

# AppIcon.icon (Icon Composer) becomes Liquid Glass on macOS 26; actool also bakes
# flattened images for older systems into Assets.car, plus AppIcon.icns.
# Absolute paths: actool hands the work to a long-lived ibtoold, which resolves relative
# paths against its own working directory, possibly another checkout.
log "compile Bundle/Assets.xcassets and Bundle/AppIcon.icon"
xcrun actool "$ROOT/Bundle/Assets.xcassets" "$ROOT/Bundle/AppIcon.icon" \
    --compile "$ROOT/$app/Contents/Resources" \
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

entitlements="$tmp/app.entitlements"
cp Bundle/App.entitlements "$entitlements"

sparkle="$app/Contents/Frameworks/Sparkle.framework"
if [[ -d $sparkle ]]; then
    # Sandboxed Sparkle installs through its Installer XPC service (sparkle-project.org/documentation/sandboxing).
    /usr/libexec/PlistBuddy -c "Add :SUEnableInstallerLauncherService bool true" "$plist"
    /usr/libexec/PlistBuddy \
        -c "Add :com.apple.security.temporary-exception.mach-lookup.global-name array" \
        -c "Add :com.apple.security.temporary-exception.mach-lookup.global-name:0 string $BUNDLE_ID-spks" \
        -c "Add :com.apple.security.temporary-exception.mach-lookup.global-name:1 string $BUNDLE_ID-spki" \
        "$entitlements"
    if [[ $config == release ]]; then
        [[ -n ${RELEASES_URL:-} && -n ${SPARKLE_PUBLIC_KEY:-} ]] ||
            die "release builds need RELEASES_URL and SPARKLE_PUBLIC_KEY in Bundle/app.env (see make sparkle-keys)"
        set_string SUFeedURL "$RELEASES_URL/latest/download/appcast.xml"
        set_string SUPublicEDKey "$SPARKLE_PUBLIC_KEY"
    fi
fi
plutil -lint -s "$plist"

case $config in
    debug)
        identity="-"
        /usr/libexec/PlistBuddy -c "Add :com.apple.security.get-task-allow bool true" "$entitlements"
        sign_args=(--force --sign -)
        ;;
    release)
        identity=$(signing_identity)
        sign_args=(--force --sign "$identity")
        # Hardened runtime exists for notarization. Its library validation needs a Team ID,
        # which ad-hoc code lacks, so an ad-hoc app would refuse its own Sparkle.framework.
        if [[ $identity != "-" ]]; then
            sign_args+=(--options runtime --timestamp)
        fi
        ;;
    mas)
        identity=$mas_identity
        ditto "$MAS_PROVISIONING_PROFILE" "$app/Contents/embedded.provisionprofile"
        /usr/libexec/PlistBuddy \
            -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" \
            -c "Add :com.apple.developer.team-identifier string $TEAM_ID" \
            "$entitlements"
        sign_args=(--force --sign "$identity")
        ;;
esac

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
