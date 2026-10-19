#!/usr/bin/env bash
# Checks a packaged DMG as a user gets it: mounts it read-only, checks the Applications
# link and smoke-tests the app inside (signature, resources, launch). With a Developer
# ID, Gatekeeper must accept the DMG and the app.
#   verify-dmg.sh <dmg>
# Packaging can break the app inside while dist/<App>.app stays valid: a Finder flag on
# the bundle, for one, fails codesign --strict.

source "$(dirname "$0")/common.sh"

dmg=${1:?usage: verify-dmg.sh <dmg>}
[[ -f $dmg ]] || die "no DMG at $dmg"

mount=$(mktemp -d)
hdiutil attach -quiet -nobrowse -readonly -noverify -mountpoint "$mount" "$dmg"
trap 'hdiutil detach -quiet "$mount" || echo "error: cannot detach $mount" >&2' EXIT

[[ $(readlink "$mount/Applications") == /Applications ]] || die "$dmg has no Applications link"
app="$mount/$APP_NAME.app"
scripts/smoke.sh "$app"
if [[ -n ${TEAM_ID:-} ]]; then
    spctl --assess --type open --context context:primary-signature -v "$dmg"
    spctl --assess --type execute -v "$app"
fi
log "dmg ok: $dmg"
