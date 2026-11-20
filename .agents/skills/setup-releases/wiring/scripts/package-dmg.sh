#!/usr/bin/env bash
# Packages $RELEASE_APP into $RELEASE_DMG (scripts/make-dmg.sh),
# then signs and notarizes the DMG (Developer ID only). Prints the DMG path on stdout.

source "$(dirname "$0")/release-common.sh"

app=$RELEASE_APP
[[ -d $app ]] || die "no app at $app; run make release-app first"
dmg=$RELEASE_DMG

scripts/make-dmg.sh "$app" "$dmg"

identity=$(signing_identity)
if [[ $identity != "-" ]]; then
    codesign --force --timestamp --sign "$identity" "$dmg"
fi
scripts/notarize.sh "$dmg"

echo "$dmg"
