#!/usr/bin/env bash
# Notarizes and staples a signed .app or .dmg. Without TEAM_ID (ad-hoc builds)
# there is nothing Apple will notarize, so it says so and stops.
#
# Credentials, first match wins:
#   NOTARY_KEY_PATH + NOTARY_KEY_ID + NOTARY_ISSUER_ID   App Store Connect API key (CI)
#   NOTARY_PROFILE                                       keychain profile from
#                                                        `xcrun notarytool store-credentials`

source "$(dirname "$0")/common.sh"

target=${1:?usage: notarize.sh <path.app|path.dmg>}
[[ -e $target ]] || die "no such file: $target"

if [[ -z ${TEAM_ID:-} ]]; then
    log "TEAM_ID empty: skipping notarization of $target (ad-hoc build)"
    exit 0
fi

if [[ -n ${NOTARY_KEY_ID:-} ]]; then
    [[ -n ${NOTARY_KEY_PATH:-} && -n ${NOTARY_ISSUER_ID:-} ]] ||
        die "NOTARY_KEY_ID needs NOTARY_KEY_PATH and NOTARY_ISSUER_ID"
    auth=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
elif [[ -n ${NOTARY_PROFILE:-} ]]; then
    auth=(--keychain-profile "$NOTARY_PROFILE")
else
    die "set NOTARY_PROFILE (local) or NOTARY_KEY_PATH/NOTARY_KEY_ID/NOTARY_ISSUER_ID (CI)"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

case "$target" in
    *.app)
        submission="$tmp/$(basename "$target").zip"
        ditto -c -k --keepParent "$target" "$submission"
        ;;
    *.dmg) submission=$target ;;
    *) die "notarize.sh only handles .app and .dmg" ;;
esac

log "notarize $target"
# The exit code of `submit --wait` does not reflect the verdict; the JSON status does.
result=$(xcrun notarytool submit "$submission" "${auth[@]}" --wait --output-format json)
status=$(jq -r .status <<<"$result")
id=$(jq -r .id <<<"$result")
if [[ $status != Accepted ]]; then
    xcrun notarytool log "$id" "${auth[@]}" >&2 || true
    die "notarization $status for $target (submission $id)"
fi

xcrun stapler staple "$target"
xcrun stapler validate "$target"
