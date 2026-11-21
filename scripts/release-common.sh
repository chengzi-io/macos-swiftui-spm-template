# Sourced by the release scripts: scripts/common.sh, plus the paths and the signing that
# only a release needs.
# shellcheck shell=bash disable=SC2034 # the scripts that source this file read its variables

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ARCHIVE="$DERIVED_DATA/$APP_NAME.xcarchive"
RELEASE_APP="dist/$APP_NAME.app"
RELEASE_DMG="dist/$APP_NAME-$VERSION.dmg"

# Prints SUPublicEDKey from App/Configs/Info.plist, the key installed copies check
# updates against; empty until scripts/sparkle-key.sh writes it.
sparkle_public_key() {
    local key
    key=$(plutil -extract SUPublicEDKey raw App/Configs/Info.plist) ||
        die "no SUPublicEDKey in App/Configs/Info.plist"
    echo "$key"
}

# Prints the codesign identity for Developer ID builds: "-" (ad-hoc) when TEAM_ID is
# empty, otherwise the team's Developer ID Application certificate.
signing_identity() {
    if [[ -z ${TEAM_ID:-} ]]; then
        echo "-"
        return
    fi
    local id
    id=$(find_identity "Developer ID Application")
    [[ -n $id ]] || die "no 'Developer ID Application' identity for team $TEAM_ID in the keychain"
    echo "$id"
}
