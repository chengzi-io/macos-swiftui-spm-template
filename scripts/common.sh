# Sourced by scripts/*.sh. Runs from the repo root with the app identity
# (App/Configs/Identity.xcconfig) exported.
# macOS ships bash 3.2: no associative arrays, no mapfile, guard empty arrays.

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

# App/<App>.xcodeproj names the app target and its scheme <App> (scripts/rename.sh renames
# them together). Only a folder with a project.pbxproj counts: Xcode can leave its window
# state behind in an old project path.
projects=(App/*.xcodeproj/project.pbxproj)
[[ ${#projects[@]} -eq 1 && -f ${projects[0]} ]] ||
    die "expected one Xcode project in App/, found: ${projects[*]}"
XCODE_PROJECT=${projects[0]%/project.pbxproj}
APP_TARGET=$(basename "$XCODE_PROJECT" .xcodeproj)

# set_identity KEY value: rewrites the KEY line of App/Configs/Identity.xcconfig.
set_identity() {
    sed -i '' -E -e "s|^$1[[:space:]]*=.*|$1 = $2|" -e 's/[[:space:]]+$//' App/Configs/Identity.xcconfig
}

# Prints SUPublicEDKey from App/Configs/Info.plist, the key installed copies check
# updates against; empty until make sparkle-keys.
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
