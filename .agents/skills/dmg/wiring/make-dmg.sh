#!/usr/bin/env bash
# Creates an unsigned DMG of an .app with an /Applications link, in the Finder window
# that Bundle/DMG/settings.py designs: background, window size, icon spots. The dmg
# skill installs it as scripts/make-dmg.sh in place of the plain version;
# package-dmg.sh signs and notarizes the result.
#   make-dmg.sh <app> <dmg>

source "$(dirname "$0")/common.sh"

app=${1:?usage: make-dmg.sh <app> <dmg>}
dmg=${2:?usage: make-dmg.sh <app> <dmg>}
[[ -d $app ]] || die "no app at $app"
[[ -f Bundle/DMG/settings.py ]] || die "no Bundle/DMG/settings.py; the dmg skill writes it"
mkdir -p "$(dirname "$dmg")"
rm -f "$dmg"

# dmgbuild writes the window layout (.DS_Store) itself instead of scripting Finder, so
# it behaves the same on CI. Hash-pinned: it runs in the release job beside the
# signing keys.
dmgbuild=.build/dmgbuild-1.6.7/bin/dmgbuild
if [[ ! -x $dmgbuild ]]; then
    python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' ||
        die "dmgbuild needs python3 3.10 or later (brew install python)"
    log "install dmgbuild into .build/dmgbuild-1.6.7"
    python3 -m venv .build/dmgbuild-1.6.7
    .build/dmgbuild-1.6.7/bin/pip install --quiet --disable-pip-version-check \
        --require-hashes --only-binary :all: -r scripts/dmgbuild-requirements.txt
fi
log "package $dmg with the Bundle/DMG design"
"$dmgbuild" -s Bundle/DMG/settings.py -D app="$app" "$APP_DISPLAY_NAME" "$dmg" >&2
