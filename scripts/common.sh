# Sourced by scripts/*.sh. Runs from the repo root with the app identity
# (App/Configs/Identity.xcconfig) exported.
# macOS ships bash 3.2: no associative arrays, no mapfile, guard empty arrays.
# shellcheck shell=bash disable=SC2034 # the scripts that source this file read its variables

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

# Identity.xcconfig is plain KEY = value lines; Xcode reads the same file.
while IFS= read -r line; do
    if [[ $line =~ ^([A-Z_][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*[^[:space:]])?[[:space:]]*$ ]]; then
        export "${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
    fi
done <App/Configs/Identity.xcconfig
export RELEASES_URL="https://github.com/$GITHUB_REPOSITORY/releases"

DERIVED_DATA=.build/xcode
VERSION=$(tr -d '[:space:]' < version.txt)
BUILD_NUMBER=$(git rev-list --count HEAD)
DEBUG_APP="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
ARCHIVE="$DERIVED_DATA/$APP_NAME.xcarchive"
RELEASE_APP="dist/$APP_NAME.app"
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin

die() {
    echo "error: $*" >&2
    exit 1
}

log() {
    echo "==> $*" >&2
}

# The Xcode project and its scheme carry APP_NAME; the targets inside are always App and
# AppUITests, so renaming the app moves the project and the scheme, not what is in them.
XCODE_PROJECT=App/$APP_NAME.xcodeproj
XCODE_SCHEME=$XCODE_PROJECT/xcshareddata/xcschemes/$APP_NAME.xcscheme
[[ -f $XCODE_PROJECT/project.pbxproj ]] ||
    die "no $XCODE_PROJECT/project.pbxproj; the project is named after APP_NAME in App/Configs/Identity.xcconfig: git mv it and its scheme to match"

# Prints one digest of every file in App/Application/AppIcon.icon and its path, so
# status.sh can tell the template's icon from the app's own.
icon_digest() {
    (cd App/Application && find AppIcon.icon -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256) |
        shasum -a 256 | awk '{ print $1 }'
}

# Prints SUPublicEDKey from App/Configs/Info.plist, the key installed copies check
# updates against; empty until the setup-releases skill's sparkle-keys.sh writes it.
sparkle_public_key() {
    local key
    key=$(plutil -extract SUPublicEDKey raw App/Configs/Info.plist) ||
        die "no SUPublicEDKey in App/Configs/Info.plist"
    echo "$key"
}

# Sets SUPublicEDKey in App/Configs/Info.plist in place, keeping the file's formatting
# (plutil and PlistBuddy rewrite it with tabs).
set_sparkle_public_key() {
    sed -i '' -e '/<key>SUPublicEDKey<\/key>/{' -e 'n' -e "s|<string>.*</string>|<string>$1</string>|" -e '}' App/Configs/Info.plist
    [[ $(plutil -extract SUPublicEDKey raw App/Configs/Info.plist) == "$1" ]] || die "could not set SUPublicEDKey in App/Configs/Info.plist"
}

# Prints the SHA-1 of the first valid codesigning identity for TEAM_ID whose name
# matches the extended regex.
find_identity() {
    local pattern=$1
    security find-identity -v -p codesigning |
        awk -v pattern="$pattern" -v team="($TEAM_ID)" '$0 ~ pattern && index($0, team) { print $2; exit }'
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
