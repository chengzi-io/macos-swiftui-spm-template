#!/usr/bin/env bash
# Writes dist/appcast.xml for the current version's DMG. The appcast lists only
# this version: it is attached to each GitHub Release and served through
# $RELEASES_URL/latest/download/appcast.xml (no delta updates).
#
# EdDSA private key: SPARKLE_ED_PRIVATE_KEY (CI) or the keychain entry created by
# the release-setup skill's sparkle-keys.sh (account = BUNDLE_ID).

source "$(dirname "$0")/common.sh"

dmg="dist/$APP_NAME-$VERSION.dmg"
[[ -f $dmg ]] || die "no DMG at $dmg; run make release-dmg first"
public_key=$(sparkle_public_key)

swift package resolve >&2
sparkle_bin=$SPARKLE_BIN
[[ -x $sparkle_bin/generate_appcast ]] || die "Sparkle tools missing at $sparkle_bin"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/updates"
ditto "$dmg" "$tmp/updates/$(basename "$dmg")"

args=(
    --download-url-prefix "$RELEASES_URL/download/v$VERSION/"
    --full-release-notes-url "$RELEASES_URL"
    --link "$RELEASES_URL"
    -o "$ROOT/dist/appcast.xml"
)
log "generate dist/appcast.xml"
if [[ -n ${SPARKLE_ED_PRIVATE_KEY:-} ]]; then
    printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | "$sparkle_bin/generate_appcast" --ed-key-file - "${args[@]}" "$tmp/updates"
else
    "$sparkle_bin/generate_appcast" --account "$BUNDLE_ID" "${args[@]}" "$tmp/updates"
fi
xcrun swift scripts/verify-appcast.swift dist/appcast.xml "$dmg" \
    "$RELEASES_URL/download/v$VERSION/$(basename "$dmg")" "$public_key"
echo "dist/appcast.xml"
