#!/usr/bin/env bash
# Full release build into dist/: universal .app (signed, notarized when TEAM_ID is
# set), DMG, dSYM zip, appcast and SHA256SUMS. Same path locally and in CI.

source "$(dirname "$0")/../common.sh"

rm -rf dist
mkdir -p dist

app=$(scripts/release/app.sh)
scripts/dev/smoke.sh "$app"
scripts/release/notarize.sh "$app"
scripts/release/dmg.sh >/dev/null

log "archive dSYM"
ditto -c -k --keepParent "$ARCHIVE/dSYMs/$APP_NAME.app.dSYM" "dist/$APP_NAME-$VERSION.dSYM.zip"

scripts/release/appcast.sh >/dev/null

(cd dist && shasum -a 256 ./*.dmg ./*.dSYM.zip appcast.xml >SHA256SUMS)
log "release artifacts in dist/:"
ls -1 dist >&2
