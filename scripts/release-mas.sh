#!/usr/bin/env bash
# Mac App Store package: builds dist/mas/$APP_NAME.app (no Sparkle) and wraps it in
# dist/mas/$APP_NAME-$VERSION.pkg signed with the team's installer certificate.
#   release-mas.sh          build the .pkg
#   release-mas.sh upload   build, then upload with the App Store Connect API key
#                           (NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER_ID)
# Needs TEAM_ID and MAS_PROVISIONING_PROFILE; see docs/RELEASING.md.

source "$(dirname "$0")/common.sh"

[[ -n ${TEAM_ID:-} ]] || die "App Store builds need TEAM_ID in Bundle/app.env"
installer=$(find_identity "3rd Party Mac Developer Installer|Mac Installer Distribution" basic)
[[ -n $installer ]] || die "no Mac Installer Distribution identity for team $TEAM_ID in the keychain"

app=$(scripts/build-app.sh mas)
pkg="dist/mas/$APP_NAME-$VERSION.pkg"
log "productbuild $pkg"
productbuild --component "$app" /Applications --sign "$installer" "$pkg"

if [[ ${1:-} == upload ]]; then
    [[ -n ${NOTARY_KEY_PATH:-} && -n ${NOTARY_KEY_ID:-} && -n ${NOTARY_ISSUER_ID:-} ]] ||
        die "upload needs NOTARY_KEY_PATH, NOTARY_KEY_ID and NOTARY_ISSUER_ID"
    log "upload $pkg"
    xcrun altool --upload-app -f "$pkg" -t macos \
        --api-key "$NOTARY_KEY_ID" --api-issuer "$NOTARY_ISSUER_ID" --p8-file-path "$NOTARY_KEY_PATH"
fi
echo "$pkg"
