#!/usr/bin/env bash
# Builds the debug .app, $DEBUG_APP: ad-hoc signed, the debugger can attach. Prints its
# path on stdout. $VERSION (scripts/common.sh) and the commit count become the version;
# Xcode's own builds keep the placeholders in App/Configs/App.xcconfig.

source "$(dirname "$0")/common.sh"

[[ $# -eq 0 ]] || die "usage: build.sh (takes no arguments)"

log "xcodebuild Debug ($VERSION build $BUILD_NUMBER)"
xcodebuild build -quiet -project "$XCODE_PROJECT" -scheme "$APP_NAME" \
    -derivedDataPath "$DERIVED_DATA" -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
codesign --verify --deep --strict "$DEBUG_APP"
echo "$DEBUG_APP"
