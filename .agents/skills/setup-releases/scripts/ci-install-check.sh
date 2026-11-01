#!/usr/bin/env bash
# CI only: proves that the setup-releases wiring installs into an app made from this
# template and that the release targets then build a DMG there, ad-hoc and without
# secrets. Copies the tracked tree, so this checkout stays untouched; needs Xcode, git and
# the package's dependencies.
#
#   ci-install-check.sh [DIR]    default: $RUNNER_TEMP/app

# shellcheck source=../../../../scripts/common.sh
source "$(dirname "$0")/../../../../scripts/common.sh"

template=$PWD
dir=${1:-${RUNNER_TEMP:?}/app}
[[ $dir != "$template" ]] || die "give a directory other than this checkout"

log "copy the tracked tree to $dir"
rm -rf "$dir"
mkdir -p "$dir"
git archive HEAD | tar -x -C "$dir"

cd "$dir"
git init -q
git add -A
git -c user.name=ci -c user.email=ci@example.invalid commit -q -m "the template"
# An app's README.md has the "## Feedback" section install.sh puts Install before.
printf '# App\n\n## Feedback\n\nOpen an issue.\n' >README.md
# A release build refuses to run while SUPublicEDKey is empty; this one signs nothing.
set_sparkle_public_key "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

log "install the release pipeline"
.agents/skills/setup-releases/scripts/install.sh

log "build the release app and its DMG"
make release-app release-dmg

dmg=$(find dist -maxdepth 1 -name '*.dmg' -print -quit)
[[ -n $dmg ]] || die "make release-dmg wrote no DMG to $dir/dist"
ls -l "$dmg"
