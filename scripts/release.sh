#!/usr/bin/env bash
# Full release build into dist/: universal .app (signed, notarized when TEAM_ID is
# set), DMG, dSYM zip, appcast and SHA256SUMS. Same path locally and in CI.
# RELEASE_DRY_RUN=1 (make release-dry-run) stops after checking the DMG: ad-hoc signed,
# not notarized, no appcast. That is all a PR can do without the signing secrets.

source "$(dirname "$0")/common.sh"

rm -rf dist
mkdir -p dist

app=$(scripts/build-app.sh release)
scripts/smoke.sh "$app"
scripts/notarize.sh "$app"
dmg=$(scripts/package-dmg.sh)
scripts/verify-dmg.sh "$dmg"

if [[ ${RELEASE_DRY_RUN:-} == 1 ]]; then
    log "dry run: release build and DMG ok; no dSYM, appcast or checksums"
    exit 0
fi

log "archive dSYM"
ditto -c -k --keepParent .build/xcode/Build/Products/Release/App.dSYM "dist/$APP_NAME-$VERSION.dSYM.zip"

scripts/appcast.sh >/dev/null

(cd dist && shasum -a 256 ./*.dmg ./*.dSYM.zip appcast.xml >SHA256SUMS)
log "release artifacts in dist/:"
ls -1 dist >&2
