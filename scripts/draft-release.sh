#!/usr/bin/env bash
# Creates the draft GitHub Release of a finished run: `make release` left the artifacts in
# dist/, so this uploads them and prints where the developer reviews and publishes them.
# While the release is a draft users see nothing, and releases/latest still serves the
# previous version; publishing creates the tag vX.Y.Z, and with it the update.
#
#   draft-release.sh <tag>
#
# Needs GH_TOKEN with contents: write. Prints the draft's HTML URL on stdout.

source "$(dirname "$0")/release-common.sh"

tag=${1:?usage: draft-release.sh <tag>}
[[ $tag == "v$VERSION" ]] ||
    die "tag $tag does not match version $VERSION (RELEASE_VERSION); run the workflow again"

# An earlier run of this workflow may have left a draft here: replace it. A published
# release is final.
if is_draft=$(gh release view "$tag" --json isDraft --jq .isDraft 2>&1); then
    [[ $is_draft == true ]] ||
        die "$tag is already published; a published release does not change, so fix the app and release the next version (docs/RELEASING.md)"
    gh release delete "$tag" --yes >/dev/null
    log "replaced the earlier draft of $tag"
elif [[ $is_draft != *"release not found"* ]]; then
    die "cannot read the release $tag: ${is_draft#gh: }"
fi

# A draft does not create the tag: GitHub creates it at the target commit when the
# developer publishes.
gh release create "$tag" \
    --draft \
    --target "$(git rev-parse HEAD)" \
    --title "$tag" \
    --notes-file .build/release-notes.md \
    "$RELEASE_DMG" \
    "dist/$APP_NAME-$VERSION.dSYM.zip" \
    dist/appcast.xml \
    dist/SHA256SUMS >/dev/null

# gh falls back to an untagged draft when the tag it is given is unusable, and such a
# release would never carry the update.
release=$(gh release view "$tag" --json isDraft,tagName,url) ||
    die "cannot read back the draft release $tag; run: gh release view $tag"
[[ $(jq -r .isDraft <<<"$release") == true ]] ||
    die "the release $tag is not a draft; see docs/RELEASING.md"
[[ $(jq -r .tagName <<<"$release") == "$tag" ]] ||
    die "GitHub made the draft as $(jq -r .tagName <<<"$release"), not $tag; delete it and run the workflow again"
jq -r .url <<<"$release"
