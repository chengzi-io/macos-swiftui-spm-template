#!/usr/bin/env bash
# Builds $APP_NAME.app from App.xcodeproj.
#   debug   → $DEBUG_APP, ad-hoc signed, debugger can attach
#   release → dist/$APP_NAME.app, universal; Developer ID + hardened runtime, or ad-hoc
# Prints the .app path on stdout. version.txt and the commit count become the
# version; Xcode's own builds keep the placeholders in Configs/App.xcconfig.

source "$(dirname "$0")/common.sh"

xcodebuild_args=(
    -quiet
    -project App.xcodeproj
    -scheme App
    -derivedDataPath "$DERIVED_DATA"
    MARKETING_VERSION="$VERSION"
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
)

case ${1:-} in
    debug)
        log "xcodebuild Debug ($VERSION build $BUILD_NUMBER)"
        xcodebuild build "${xcodebuild_args[@]}" -configuration Debug \
            -destination "platform=macOS,arch=$(uname -m)"
        codesign --verify --deep --strict "$DEBUG_APP"
        echo "$DEBUG_APP"
        exit 0
        ;;
    release) ;;
    *) die "usage: build-app.sh debug|release" ;;
esac

[[ -n ${GITHUB_REPOSITORY:-} && -n ${SPARKLE_PUBLIC_KEY:-} ]] ||
    die "release builds need GITHUB_REPOSITORY in Configs/Identity.xcconfig and SUPublicEDKey in Configs/Info.plist (see make sparkle-keys)"

log "xcodebuild archive Release ($VERSION build $BUILD_NUMBER)"
rm -rf "$ARCHIVE"
xcodebuild archive "${xcodebuild_args[@]}" -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$ARCHIVE"

app=$RELEASE_APP
rm -rf "$app"
mkdir -p "$(dirname "$app")"
ditto "$ARCHIVE/Products/Applications/$APP_NAME.app" "$app"

# Xcode signs ad-hoc. Re-sign with the release identity, keeping the entitlements
# Xcode resolved from Configs/App.entitlements.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
entitlements="$tmp/app.entitlements"
codesign -d --entitlements - --xml "$app" >"$entitlements"

identity=$(signing_identity)
sign_args=(--force --sign "$identity")
# Hardened runtime exists for notarization. Its library validation needs a Team ID,
# which ad-hoc code lacks, so an ad-hoc app would refuse its own Sparkle.framework.
if [[ $identity != "-" ]]; then
    sign_args+=(--options runtime --timestamp)
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
