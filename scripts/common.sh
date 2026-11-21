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

DERIVED_DATA=.build/xcode
# RELEASE_VERSION (CI, and `make release RELEASE_VERSION=x`), else the newest vX.Y.Z tag
# reachable from HEAD without the v, else 0.0.0 before the first release. git-cliff
# computes a release's version; scripts/release-prepare.sh passes it on.
VERSION=${RELEASE_VERSION:-}
if [[ -z $VERSION ]]; then
    # vX.Y.Z only: a tag in another shape, such as v1 or a beta, must not set the version.
    VERSION=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' --exclude '*-*' 2>/dev/null || true)
    VERSION=${VERSION#v}
    [[ -n $VERSION ]] || VERSION=0.0.0
fi
BUILD_NUMBER=$(git rev-list --count HEAD)
DEBUG_APP="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
# Every Swift source: swift format formats and lints these, lint-rules.sh checks them. All
# of App/: an extension's target gets its own folder there.
SWIFT_PATHS=(Package.swift App Sources Tests)

die() {
    echo "error: $*" >&2
    exit 1
}

log() {
    echo "==> $*" >&2
}

# say <state> <text>: one checklist line, as doctor.sh and status.sh print them: the
# state (ok, todo, info, warn, --, ?) padded to five columns, then the text.
say() {
    printf '%-5s %s\n' "$1" "$2"
}

# deployment_target [xcconfig]: prints the MACOSX_DEPLOYMENT_TARGET the xcconfig sets
# (default App/Configs/Project.xcconfig), such as 14.0; dies when it sets none.
deployment_target() {
    local xcconfig=${1:-App/Configs/Project.xcconfig} value
    value=$(sed -nE 's/^MACOSX_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*([^[:space:]]+).*/\1/p' "$xcconfig")
    [[ -n $value ]] || die "no MACOSX_DEPLOYMENT_TARGET in $xcconfig"
    echo "$value"
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

# Prints the SHA-1 of the first valid codesigning identity for TEAM_ID whose name
# matches the extended regex.
find_identity() {
    local pattern=$1
    security find-identity -v -p codesigning |
        awk -v pattern="$pattern" -v team="($TEAM_ID)" '$0 ~ pattern && index($0, team) { print $2; exit }'
}
