#!/usr/bin/env bash
# Builds the release .app: $RELEASE_APP, universal, signed with the Developer ID of
# TEAM_ID and the hardened runtime, or ad-hoc without one. Prints the .app path on
# stdout. $VERSION (scripts/common.sh) and the commit count become the version.

source "$(dirname "$0")/../common.sh"

public_key=$(sparkle_public_key)
[[ -n ${GITHUB_REPOSITORY:-} && -n $public_key ]] ||
    die "release builds need GITHUB_REPOSITORY in App/Configs/Identity.xcconfig and SUPublicEDKey in App/Configs/Info.plist; run make sparkle-key and commit App/Configs/Info.plist"

# The build number counts commits, and a shallow clone has only the last few: the
# release would get a lower number than the one before, and Sparkle would not offer it.
[[ $(git rev-parse --is-shallow-repository) == false ]] ||
    die "this clone is shallow, so the build number would go back; run git fetch --unshallow"

log "xcodebuild archive Release ($VERSION build $BUILD_NUMBER)"
rm -rf "$ARCHIVE"
xcodebuild archive -quiet -project "$XCODE_PROJECT" -scheme "$XCODE_SCHEME_NAME" \
    -derivedDataPath "$DERIVED_DATA" -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

app=$RELEASE_APP
rm -rf "$app"
mkdir -p "$(dirname "$app")"
ditto "$ARCHIVE/Products/Applications/$APP_NAME.app" "$app"

# Xcode signs ad-hoc. Re-sign with the release identity, keeping the entitlements
# Xcode resolved from App/Configs/App.entitlements.
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
# An app without entitlements gets an empty file, and codesign crashes on one.
if [[ -s $entitlements ]]; then
    codesign "${sign_args[@]}" --entitlements "$entitlements" "$app"
else
    codesign "${sign_args[@]}" "$app"
fi
codesign --verify --deep --strict "$app"

echo "$app"
