# Sourced by scripts/*.sh. Runs from the repo root with the app identity
# (Configs/Identity.xcconfig) exported.
# macOS ships bash 3.2: no associative arrays, no mapfile, guard empty arrays.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

# Identity.xcconfig is plain KEY = value lines; Xcode reads the same file.
while IFS= read -r line; do
    if [[ $line =~ ^([A-Z_][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*[^[:space:]])?[[:space:]]*$ ]]; then
        export "${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
    fi
done <Configs/Identity.xcconfig
export RELEASES_URL="https://github.com/$GITHUB_REPOSITORY/releases"
SPARKLE_PUBLIC_KEY=$(plutil -extract SUPublicEDKey raw Configs/Info.plist)
export SPARKLE_PUBLIC_KEY

PACKAGE_DIR=Packages/AppModules
DERIVED_DATA=.build/xcode
VERSION=$(tr -d '[:space:]' < version.txt)
BUILD_NUMBER=$(git rev-list --count HEAD)
DEBUG_APP="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
ARCHIVE="$DERIVED_DATA/$APP_NAME.xcarchive"
RELEASE_APP="dist/$APP_NAME.app"
SPARKLE_BIN="$PACKAGE_DIR/.build/artifacts/sparkle/Sparkle/bin"

die() {
    echo "error: $*" >&2
    exit 1
}

log() {
    echo "==> $*" >&2
}

# The app's Xcode project names the app target, its scheme and its source folder:
# <App>.xcodeproj, <App>/, <App>UITests/ (scripts/rename.sh renames them together).
# Only a folder with a project.pbxproj counts: Xcode can leave its window state behind
# in an old project path.
projects=(*.xcodeproj/project.pbxproj)
[[ ${#projects[@]} -eq 1 && -f ${projects[0]} ]] ||
    die "expected one Xcode project at the repository root, found: ${projects[*]}"
APP_TARGET=${projects[0]%.xcodeproj/project.pbxproj}

# set_identity KEY value: rewrites the KEY line of Configs/Identity.xcconfig.
set_identity() {
    sed -i '' -E -e "s|^$1[[:space:]]*=.*|$1 = $2|" -e 's/[[:space:]]+$//' Configs/Identity.xcconfig
}

# Sets SUPublicEDKey in Configs/Info.plist in place, keeping the file's formatting
# (plutil and PlistBuddy rewrite it with tabs).
set_sparkle_public_key() {
    sed -i '' -e '/<key>SUPublicEDKey<\/key>/{' -e 'n' -e "s|<string>.*</string>|<string>$1</string>|" -e '}' Configs/Info.plist
    [[ $(plutil -extract SUPublicEDKey raw Configs/Info.plist) == "$1" ]] || die "could not set SUPublicEDKey in Configs/Info.plist"
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
