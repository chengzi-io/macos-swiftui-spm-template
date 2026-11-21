#!/usr/bin/env bash
# Computes the next release of this app from the commits since the last one, and writes
# its notes: the first step of the Release workflow (.github/workflows/release.yml).
#
#   release-prepare.sh [VERSION]
#
# VERSION: X.Y.Z, optional; empty computes it from the commits since the last release.
# Prints the version on stdout, one line; everything else goes to stderr.
# Writes .build/release-notes.md, the body of the draft GitHub Release.

# common.sh exports Identity.xcconfig's keys, GITHUB_REPOSITORY among them; the values
# GitHub Actions set are the ones to compare with, so read them before sourcing it.
actions=${GITHUB_ACTIONS:-}
ref=${GITHUB_REF:-}
repository=${GITHUB_REPOSITORY:-}

source "$(dirname "$0")/release-common.sh"

command -v git-cliff >/dev/null ||
    die "git-cliff missing; run: brew install git-cliff (CI downloads a pinned copy)"

# newest_tag: the newest vX.Y.Z tag reachable from HEAD, empty before the first release.
# The same rule as VERSION in scripts/common.sh.
newest_tag() {
    git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' --exclude '*-*' 2>/dev/null || true
}

# newer A B: true when the X.Y.Z version A is newer than B.
newer() {
    local i
    local -a a b
    local IFS=.
    read -r -a a <<<"$1"
    read -r -a b <<<"$2"
    for i in 0 1 2; do
        if ((10#${a[i]} != 10#${b[i]})); then
            ((10#${a[i]} > 10#${b[i]}))
            return
        fi
    done
    return 1
}

# 1. Where this runs. A release builds main, in the repository the app names, so the
# workflow's identity has to match App/Configs/Identity.xcconfig.
if [[ -n $actions ]]; then
    [[ $ref == refs/heads/main ]] ||
        die "a release runs on main, not ${ref:-an unnamed ref}; merge the PR and run the workflow on main"
    # Case-insensitive, and no ${x,,} on macOS's bash 3.2.
    workflow_repo=$(printf '%s' "$repository" | tr '[:upper:]' '[:lower:]')
    id_repo=$(printf '%s' "${GITHUB_REPOSITORY:-}" | tr '[:upper:]' '[:lower:]')
    [[ $workflow_repo == "$id_repo" ]] ||
        die "App/Configs/Identity.xcconfig releases from ${GITHUB_REPOSITORY:-nothing}, but this workflow runs in $repository; initialize the project first"
fi

# 2. The update-signing key: a release build refuses an empty one, and installed copies
# check every update against it.
key=$(plutil -extract SUPublicEDKey raw App/Configs/Info.plist 2>/dev/null || true)
[[ -n $key ]] ||
    die "SUPublicEDKey in App/Configs/Info.plist is empty; run make sparkle-key and commit App/Configs/Info.plist"

# 3. The secrets the release signs and notarizes with arrive from the release
# environment. A local run holds them in the keychain instead, so it skips this.
secrets=(SPARKLE_ED_PRIVATE_KEY)
if [[ -n ${TEAM_ID:-} ]]; then
    secrets+=(DEVELOPER_ID_P12_BASE64 DEVELOPER_ID_P12_PASSWORD NOTARY_API_KEY_P8_BASE64 NOTARY_API_KEY_ID NOTARY_API_ISSUER_ID)
fi
if [[ -n $actions ]]; then
    for secret in "${secrets[@]}"; do
        [[ -n ${!secret:-} ]] ||
            die "the release environment lacks the secret $secret; store it as docs/RELEASING.md describes"
    done
fi

# 4. Something to release: a feat, a fix or a breaking change since the last tag, which
# the checks below need too. It runs before the version, because a history without one
# leaves git-cliff's version at the last tag, whose "not newer" would hide the cause. An
# explicit VERSION does not lift this, since that release would ship no change.
last_tag=$(newest_tag)
releasable=$(git cliff --unreleased --context |
    jq '[.[].commits[] | select(.breaking or .group == "Features" or .group == "Fixes")] | length') ||
    die "cannot read the commits since the last release; run: git cliff --unreleased --context"
[[ $releasable -gt 0 ]] ||
    die "nothing to release since ${last_tag:-the first commit}: only chore, docs, ci, ... commits"

# 5. The version: the argument when given, else git-cliff's bump of those commits. Either
# must be newer than the last tag, and its tag must not exist yet.
version=${1:-}
if [[ -n $version ]]; then
    [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
        die "version $version is not X.Y.Z; pass three numbers, such as 1.2.3"
else
    version=$(git cliff --bumped-version) ||
        die "git-cliff cannot compute the next version; run: git cliff --bumped-version"
    version=${version#v}
fi
if [[ -n $last_tag ]] && ! newer "$version" "${last_tag#v}"; then
    die "version $version is not newer than the last release $last_tag; pass a higher version, or leave VERSION empty"
fi
if git rev-parse -q --verify "refs/tags/v$version" >/dev/null; then
    die "tag v$version already exists; pass another version, or leave VERSION empty"
fi
# A draft release has no tag, so an earlier run's draft never blocks this. A clone
# without a remote skips the check; the workflow always has one.
if git ls-remote --exit-code --tags origin "refs/tags/v$version" >/dev/null 2>&1; then
    die "tag v$version is already on origin; pass another version, or leave VERSION empty"
fi

mkdir -p .build
git cliff --unreleased --tag "v$version" --output .build/release-notes.md

# An ad-hoc build is blocked by Gatekeeper on its first launch, and the note is the only
# place the release says so.
if [[ -z ${TEAM_ID:-} ]]; then
    cat >>.build/release-notes.md <<'EOF'

---

> [!NOTE]
> This build is not signed with a Developer ID or notarized. macOS will refuse to
> open it the first time: open System Settings → Privacy & Security and click
> **Open Anyway**. Later updates install through the app's own updater.
EOF
fi

echo "$version"
