#!/usr/bin/env bash
# Builds $APP_NAME.app from $XCODE_PROJECT.
#   debug   → $DEBUG_APP, ad-hoc signed, debugger can attach
#   release → dist/$APP_NAME.app, universal; Developer ID + hardened runtime, or ad-hoc
#   mas     → dist/mas/$APP_NAME.app, universal, no Sparkle; Apple Distribution signed
#             with the Mac App Store profile. Needs TEAM_ID and MAS_PROVISIONING_PROFILE
# Prints the .app path on stdout. version.txt and the commit count become the
# version; Xcode's own builds keep the placeholders in App/Configs/App.xcconfig.

source "$(dirname "$0")/common.sh"

xcodebuild_args=(
    -quiet
    -project "$XCODE_PROJECT"
    -derivedDataPath "$DERIVED_DATA"
    MARKETING_VERSION="$VERSION"
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
)

config=${1:-}
case $config in
    debug)
        log "xcodebuild Debug ($VERSION build $BUILD_NUMBER)"
        xcodebuild build "${xcodebuild_args[@]}" -scheme "$APP_TARGET" -configuration Debug \
            -destination "platform=macOS,arch=$(uname -m)"
        codesign --verify --deep --strict "$DEBUG_APP"
        echo "$DEBUG_APP"
        exit 0
        ;;
    release)
        public_key=$(sparkle_public_key)
        [[ -n ${GITHUB_REPOSITORY:-} && -n $public_key ]] ||
            die "release builds need GITHUB_REPOSITORY in App/Configs/Identity.xcconfig and SUPublicEDKey in App/Configs/Info.plist (see the release-setup skill)"
        scheme=$APP_TARGET
        archive=$ARCHIVE
        app=$RELEASE_APP
        identity=$(signing_identity)
        ;;
    mas)
        [[ -n ${TEAM_ID:-} ]] || die "App Store builds need TEAM_ID in App/Configs/Identity.xcconfig"
        [[ -f ${MAS_PROVISIONING_PROFILE:-} ]] ||
            die "set MAS_PROVISIONING_PROFILE to the Mac App Store .provisionprofile"
        identity=$(find_identity "Apple Distribution|3rd Party Mac Developer Application")
        [[ -n $identity ]] || die "no Apple Distribution identity for team $TEAM_ID in the keychain"
        scheme=AppStore
        archive="$DERIVED_DATA/$APP_NAME-mas.xcarchive"
        app="dist/mas/$APP_NAME.app"
        ;;
    *) die "usage: build-app.sh debug|release|mas" ;;
esac

# The build number counts commits, and a shallow clone has only the last few: the
# release would get a lower number than the one before, and Sparkle would not offer it.
[[ $(git rev-parse --is-shallow-repository) == false ]] ||
    die "this clone is shallow, so the build number would go back; run git fetch --unshallow"

log "xcodebuild archive $scheme ($VERSION build $BUILD_NUMBER)"
rm -rf "$archive"
xcodebuild archive "${xcodebuild_args[@]}" -scheme "$scheme" -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$archive"

rm -rf "$app"
mkdir -p "$(dirname "$app")"
ditto "$archive/Products/Applications/$APP_NAME.app" "$app"

# Xcode signs ad-hoc. Re-sign with the release identity, keeping the entitlements
# Xcode resolved from the target's .entitlements file.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
entitlements="$tmp/app.entitlements"
codesign -d --entitlements - --xml "$app" >"$entitlements"

sign_args=(--force --sign "$identity")
case $config in
    release)
        # Hardened runtime exists for notarization. Its library validation needs a Team
        # ID, which ad-hoc code lacks, so an ad-hoc app would refuse its own Sparkle.framework.
        if [[ $identity != "-" ]]; then
            sign_args+=(--options runtime --timestamp)
        fi
        ;;
    mas)
        ditto "$MAS_PROVISIONING_PROFILE" "$app/Contents/embedded.provisionprofile"
        /usr/libexec/PlistBuddy \
            -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" \
            -c "Add :com.apple.developer.team-identifier string $TEAM_ID" \
            "$entitlements"
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
# An app without entitlements gets an empty file, and codesign crashes on one.
if [[ -s $entitlements ]]; then
    codesign "${sign_args[@]}" --entitlements "$entitlements" "$app"
else
    codesign "${sign_args[@]}" "$app"
fi
codesign --verify --deep --strict "$app"

echo "$app"
