#!/usr/bin/env bash
# Creates an unsigned DMG of an .app with an /Applications link.
#   make-dmg.sh <app> <dmg>
# With Bundle/DMG/settings.py (written by the brand skill, .claude/skills/brand) the
# Finder window gets that background and layout; without it the window is plain.

source "$(dirname "$0")/common.sh"

app=${1:?usage: make-dmg.sh <app> <dmg>}
dmg=${2:?usage: make-dmg.sh <app> <dmg>}
[[ -d $app ]] || die "no app at $app"
mkdir -p "$(dirname "$dmg")"
rm -f "$dmg"

if [[ ! -f Bundle/DMG/settings.py ]]; then
    log "package $dmg"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    ditto "$app" "$tmp/stage/$(basename "$app")"
    ln -s /Applications "$tmp/stage/Applications"
    hdiutil create -quiet -volname "$APP_DISPLAY_NAME" -srcfolder "$tmp/stage" -format UDZO "$dmg"
    exit 0
fi

# dmgbuild writes the window layout (.DS_Store) itself instead of scripting Finder, so
# it behaves the same on CI. Hash-pinned: it runs in the release job beside the
# signing keys.
dmgbuild=.build/dmgbuild-1.6.7/bin/dmgbuild
if [[ ! -x $dmgbuild ]]; then
    python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' ||
        die "Bundle/DMG needs python3 3.10 or later for dmgbuild (brew install python)"
    log "install dmgbuild into .build/dmgbuild-1.6.7"
    python3 -m venv .build/dmgbuild-1.6.7
    .build/dmgbuild-1.6.7/bin/pip install --quiet --disable-pip-version-check \
        --require-hashes --only-binary :all: -r scripts/dmgbuild-requirements.txt
fi
log "package $dmg with the Bundle/DMG design"
"$dmgbuild" -s Bundle/DMG/settings.py -D app="$app" "$APP_DISPLAY_NAME" "$dmg" >&2
