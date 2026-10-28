#!/usr/bin/env bash
# First run after "Use this template": makes the template yours, then deletes itself.
#
#   scripts/init.sh --name MyApp --bundle-id com.example.myapp \
#     [--display-name "My App"] [--copyright "Jane Doe"] \
#     [--repo owner/repo] [--codeowner @user-or-@org/team]
#
# --repo defaults to the origin remote, --copyright to the repository owner,
# --codeowner to you, as gh is signed in. Needs a clean working tree; review
# `git diff HEAD`, then commit.

source "$(dirname "$0")/common.sh"

usage() {
    sed -n '4,6p' "$0" | sed 's/^#  //' >&2
    exit 1
}

name="" bundle_id="" display_name="" holder="" repo="" codeowner=""
while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 ]] || usage
    case $1 in
        --name) name=$2 ;;
        --bundle-id) bundle_id=$2 ;;
        --display-name) display_name=$2 ;;
        --copyright) holder=$2 ;;
        --repo) repo=$2 ;;
        --codeowner) codeowner=$2 ;;
        *) usage ;;
    esac
    shift 2
done
[[ -n $name && -n $bundle_id ]] || usage

[[ $name =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || die "--name must be letters and digits; it names the .app and the executable"
[[ $bundle_id =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || die "--bundle-id must look like com.example.myapp"

# Tools init and rename.sh need, checked before any file changes.
command -v jq >/dev/null || die "jq missing (ships with macOS 15+); run: brew install jq"
xcodebuild -version >/dev/null 2>&1 ||
    die "xcodebuild does not run; install Xcode 26, then: sudo xcode-select -s /Applications/Xcode.app"
if [[ -z $codeowner ]]; then
    command -v gh >/dev/null || die "gh missing; run: brew install gh, or pass --codeowner @user-or-@org/team"
    gh auth status >/dev/null 2>&1 || die "gh is not signed in; run: gh auth login, or pass --codeowner @user-or-@org/team"
fi
[[ -z $(git status --porcelain) ]] || die "commit or stash your changes first, so the init diff stays reviewable"

if [[ -z $repo ]]; then
    remote=$(git remote get-url origin) || die "no origin remote; pass --repo owner/repo"
    repo=$(sed -E 's#^(git@[^:]+:|ssh://[^/]+/|https?://[^/]+/)##; s#\.git$##' <<<"$remote")
fi
[[ $repo =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || die "cannot read owner/repo from '$repo'; pass --repo owner/repo"
owner=${repo%%/*}
display_name=${display_name:-$name}
holder=${holder:-$owner}
# CODEOWNERS ignores a bare organization, which the repository owner may be.
if [[ -z $codeowner ]]; then
    login=$(gh api user --jq .login 2>/dev/null) ||
        die "pass --codeowner @user or @org/team; gh is not signed in to look you up"
    codeowner=@$login
fi
for value in "$display_name" "$holder" "$codeowner"; do
    [[ $value != *[\"\$\\\`\|\&]* ]] || die "values cannot contain \" \$ \\ \` | or &: $value"
    # Identity.xcconfig would read the rest of the line as a comment.
    [[ $value != *//* ]] || die "values cannot contain //: $value"
done
year=$(date +%Y)

# From here on init edits files. The tree was clean, so git undoes a run that stops halfway.
trap 'status=$?; ((status == 0)) || echo "error: init stopped halfway; undo its changes with: git reset --hard && git clean -fd" >&2' EXIT

# Before rename.sh, which works only on an unreleased version.
log "reset version to 0.0.0"
echo 0.0.0 >version.txt
printf '{\n  ".": "0.0.0"\n}\n' >.release-please-manifest.json
rm -f CHANGELOG.md

"$ROOT/scripts/rename.sh" --name "$name" --bundle-id "$bundle_id" --display-name "$display_name"
log "releases from $repo"
set_identity COPYRIGHT "Copyright © $year $holder"
set_identity GITHUB_REPOSITORY "$repo"
set_identity TEAM_ID ""
set_sparkle_public_key ""

# View snapshot references hold one macOS major's controls, and CI compares them: both
# follow this Mac. The demo's references come from the template's Mac.
macos_major=$(sw_vers -productVersion | cut -d. -f1)
log "CI and releases on macos-$macos_major like this Mac; drop the demo's snapshot references"
sed -i '' -E "s/runs-on: macos-[0-9]+/runs-on: macos-$macos_major/" .github/workflows/ci.yml .github/workflows/release.yml
find Tests -type d -name __Snapshots__ -prune -exec rm -rf {} +

# Deletes the marked template-only blocks, then squeezes the blank lines they leave.
drop_template_blocks() {
    local file=$1 start=$2 end=$3 content
    sed -i '' "/$start/,/$end/d" "$file"
    content=$(cat -s "$file")
    printf '%s\n' "$content" >"$file"
}

log "update LICENSE, CODEOWNERS, issue templates"
sed -i '' "s|^Copyright (c) .*|Copyright (c) $year $holder|" LICENSE
sed -i '' "s|@[A-Za-z0-9_/-]*|$codeowner|g" .github/CODEOWNERS
sed -i '' "s|github.com/[^/]*/[^/]*/security|github.com/$repo/security|" .github/ISSUE_TEMPLATE/config.yml

# README.md is the app's page for its users; developer docs stay in docs/. The DMG
# paragraph opens Install: the homebrew-cask skill adds its command after it.
log "replace README with a page for $display_name's users"
min_macos=$(sed -nE 's/^MACOSX_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' App/Configs/Project.xcconfig)
[[ -n $min_macos ]] || die "no MACOSX_DEPLOYMENT_TARGET in App/Configs/Project.xcconfig"
cat >README.md <<EOF
# $display_name

[![Latest release](https://img.shields.io/github/v/release/$repo)](https://github.com/$repo/releases/latest)
![macOS $min_macos+](https://img.shields.io/badge/macOS-$min_macos%2B-000000?logo=apple)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

_What $display_name does and for whom, in one sentence._

<!-- Replace the line above and add a screenshot. This page is for people who use the
     app; developer docs live in docs/. -->

## Install

Download the DMG from the [latest release](https://github.com/$repo/releases/latest),
open it and drag $name to Applications. $display_name runs on macOS $min_macos or later.

<!-- Delete this paragraph once TEAM_ID is set in App/Configs/Identity.xcconfig: apps
     signed with a Developer ID open without it. -->
macOS blocks the first launch because the app is not notarized yet: open System
Settings → Privacy & Security and click **Open Anyway**, once.

## Update

$display_name updates itself: choose **Check for Updates…** in the app menu, or turn on
**Automatically check for updates** in Settings.

## Feedback

[Report a bug](https://github.com/$repo/issues/new/choose). Report security issues
privately, as [SECURITY.md](.github/SECURITY.md) describes.

## Development

Setup, commands and layout: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). How releases
ship: [docs/RELEASING.md](docs/RELEASING.md).

## License

[MIT](LICENSE)
EOF

log "remove template-only files and sections"
drop_template_blocks AGENTS.md '<!-- template-only:start -->' '<!-- template-only:end -->'
drop_template_blocks Makefile '^# template-only:start' '^# template-only:end'
rm -f "$ROOT/scripts/init.sh"

cat >&2 <<EOF

Done. Review with \`git diff HEAD\` (renames are staged), then commit, for example:
  git add -A && git commit -m "chore: initialize $name from template"

Next:
  1. make setup, then make snapshots to record the demo's view snapshots on this Mac
     (look at the images in Tests/**/__Snapshots__ and commit them), then make ci
     and make run
  2. Replace the Notes demo (Sources/Notes, Sources/Features/Notes; AGENTS.md
     lists the rest) and the icon (App/Application/AppIcon.icon in Icon Composer,
     or the app-icon skill in .agents/skills/app-icon), and say what the app does
     at the top of README.md.
  3. One-time release setup: docs/RELEASING.md (make github-setup, GitHub App,
     make sparkle-keys, optional Developer ID).
EOF
