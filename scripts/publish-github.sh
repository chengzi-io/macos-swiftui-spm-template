#!/usr/bin/env bash
# Uploads dist/ release artifacts to the GitHub Release <tag> that release-please
# created. Ad-hoc builds get a note on how to open an app Gatekeeper cannot verify.
# Needs GH_TOKEN with contents:write.

source "$(dirname "$0")/common.sh"

tag=${1:?usage: publish-github.sh <tag>}
[[ $tag == "v$VERSION" ]] || die "tag $tag does not match version.txt ($VERSION)"

gh release upload "$tag" \
    "dist/$APP_NAME-$VERSION.dmg" \
    "dist/$APP_NAME-$VERSION.dSYM.zip" \
    dist/appcast.xml \
    dist/SHA256SUMS \
    --clobber

if [[ -z ${TEAM_ID:-} ]]; then
    notes=$(mktemp)
    trap 'rm -f "$notes"' EXIT
    gh release view "$tag" --json body --jq .body >"$notes"
    cat >>"$notes" <<'EOF'

---

> [!NOTE]
> This build is not signed with a Developer ID or notarized. macOS will refuse to
> open it the first time: open System Settings → Privacy & Security and click
> **Open Anyway**. Later updates install through the app's own updater.
EOF
    gh release edit "$tag" --notes-file "$notes"
fi
log "published $tag"
