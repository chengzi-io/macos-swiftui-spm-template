# Sourced by scripts/*.sh. Runs from the repo root with Bundle/app.env loaded.
# macOS ships bash 3.2: no associative arrays, no mapfile, guard empty arrays.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

set -a
# shellcheck source=../Bundle/app.env
source Bundle/app.env
set +a

VERSION=$(tr -d '[:space:]' < version.txt)
BUILD_NUMBER=$(git rev-list --count HEAD)
DEBUG_APP=".build/app/Debug/$APP_NAME.app"
RELEASE_APP="dist/$APP_NAME.app"

die() {
    echo "error: $*" >&2
    exit 1
}

log() {
    echo "==> $*" >&2
}

# Prints the codesign identity: "-" (ad-hoc) when TEAM_ID is empty,
# otherwise the SHA-1 of the team's Developer ID Application certificate.
signing_identity() {
    if [[ -z "${TEAM_ID:-}" ]]; then
        echo "-"
        return
    fi
    local id
    id=$(security find-identity -v -p codesigning |
        awk -v team="($TEAM_ID)" '/Developer ID Application/ && index($0, team) { print $2; exit }')
    [[ -n "$id" ]] || die "no 'Developer ID Application' identity for team $TEAM_ID in the keychain"
    echo "$id"
}
