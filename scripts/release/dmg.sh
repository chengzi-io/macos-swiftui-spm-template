#!/usr/bin/env bash
# Packages $RELEASE_APP into $RELEASE_DMG: the app beside an /Applications link in a plain
# Finder window, signed with the Developer ID unless TEAM_ID is empty, notarized, then
# checked as a user gets it. Prints the DMG path on stdout.

source "$(dirname "$0")/../common.sh"

app=$RELEASE_APP
[[ -d $app ]] || die "no app at $app; run scripts/release/app.sh first"
dmg=$RELEASE_DMG

tmp=$(mktemp -d)
mount=""
cleanup() {
    [[ -z $mount ]] || hdiutil detach -quiet "$mount" || echo "error: cannot detach $mount" >&2
    rm -rf "$tmp"
}
trap cleanup EXIT

# create_dmg <app> <dmg>: the image itself, before signing and notarization. It stages the
# app under $tmp, which the trap above removes. A designed window replaces this function
# alone (the macos-dmg-window skill uses dmgbuild).
create_dmg() {
    local app=$1 dmg=$2
    mkdir -p "$(dirname "$dmg")"
    rm -f "$dmg"
    log "package $dmg"
    ditto "$app" "$tmp/stage/$(basename "$app")"
    ln -s /Applications "$tmp/stage/Applications"
    hdiutil create -quiet -volname "$APP_DISPLAY_NAME" -srcfolder "$tmp/stage" -format UDZO "$dmg"
}

create_dmg "$app" "$dmg"

identity=$(signing_identity)
if [[ $identity != "-" ]]; then
    codesign --force --timestamp --sign "$identity" "$dmg"
fi
scripts/release/notarize.sh "$dmg"

# Packaging can break the app inside while $app stays valid: a Finder flag on the bundle,
# for one, fails codesign --strict inside the DMG. So check the DMG as a user gets it:
# mounted read-only, with its Applications link, and the app inside smoke-tested.
mount=$tmp/mnt
mkdir -p "$mount"
hdiutil attach -quiet -nobrowse -readonly -noverify -mountpoint "$mount" "$dmg"
[[ $(readlink "$mount/Applications") == /Applications ]] || die "$dmg has no Applications link"
mounted_app="$mount/$APP_NAME.app"
scripts/dev/smoke.sh "$mounted_app"
if [[ -n ${TEAM_ID:-} ]]; then
    spctl --assess --type open --context context:primary-signature -v "$dmg"
    spctl --assess --type execute -v "$mounted_app"
fi
log "dmg ok: $dmg"

echo "$dmg"
