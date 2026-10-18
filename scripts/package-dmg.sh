#!/usr/bin/env bash
# Packages dist/$APP_NAME.app into dist/$APP_NAME-$VERSION.dmg with an
# /Applications link, then signs and notarizes the DMG (Developer ID only).
# Prints the DMG path on stdout.

source "$(dirname "$0")/common.sh"

app=$RELEASE_APP
[[ -d $app ]] || die "no app at $app; run make release-app first"
dmg="dist/$APP_NAME-$VERSION.dmg"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

log "package $dmg"
ditto "$app" "$tmp/stage/$APP_NAME.app"
ln -s /Applications "$tmp/stage/Applications"
rm -f "$dmg"
hdiutil create -quiet -volname "$APP_DISPLAY_NAME" -srcfolder "$tmp/stage" -format UDZO "$dmg"

identity=$(signing_identity)
if [[ $identity != "-" ]]; then
    codesign --force --timestamp --sign "$identity" "$dmg"
fi
scripts/notarize.sh "$dmg"

echo "$dmg"
