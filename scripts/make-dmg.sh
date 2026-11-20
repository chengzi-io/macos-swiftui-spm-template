# Creates an unsigned DMG of an .app with an /Applications link, in a plain Finder
# window. package-dmg.sh signs and notarizes it. A designed window uses the same
# arguments; that wiring is done by the macos-dmg-window skill in the
# chengzi-io/skills macos plugin, not by this repository.
#   make-dmg.sh <app> <dmg>

source "$(dirname "$0")/common.sh"

app=${1:?usage: make-dmg.sh <app> <dmg>}
dmg=${2:?usage: make-dmg.sh <app> <dmg>}
[[ -d $app ]] || die "no app at $app"
mkdir -p "$(dirname "$dmg")"
rm -f "$dmg"

log "package $dmg"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ditto "$app" "$tmp/stage/$(basename "$app")"
ln -s /Applications "$tmp/stage/Applications"
hdiutil create -quiet -volname "$APP_DISPLAY_NAME" -srcfolder "$tmp/stage" -format UDZO "$dmg"
