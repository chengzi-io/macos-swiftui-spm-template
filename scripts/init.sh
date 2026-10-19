#!/usr/bin/env bash
# First run after "Use this template": makes the template yours, then deletes itself.
#
#   scripts/init.sh --name MyApp --bundle-id com.example.myapp \
#     [--display-name "My App"] [--copyright "Jane Doe"] \
#     [--repo owner/repo] [--codeowner @user-or-@org/team]
#
# --repo defaults to the origin remote, --copyright to the repository owner,
# --codeowner to @owner. Needs a clean working tree; review `git diff`, then commit.

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
[[ -z $(git status --porcelain) ]] || die "commit or stash your changes first, so the init diff stays reviewable"

if [[ -z $repo ]]; then
    remote=$(git remote get-url origin) || die "no origin remote; pass --repo owner/repo"
    repo=$(sed -E 's#^(git@[^:]+:|ssh://[^/]+/|https?://[^/]+/)##; s#\.git$##' <<<"$remote")
fi
[[ $repo =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || die "cannot read owner/repo from '$repo'; pass --repo owner/repo"
owner=${repo%%/*}
display_name=${display_name:-$name}
holder=${holder:-$owner}
codeowner=${codeowner:-@$owner}
for value in "$display_name" "$holder" "$codeowner"; do
    [[ $value != *[\"\$\\\`\|\&]* ]] || die "values cannot contain \" \$ \\ \` | or &: $value"
done
year=$(date +%Y)

log "app identity: $name ($bundle_id), releases from $repo"
set_env() { sed -i '' "s|^$1=.*|$1=$2|" Bundle/app.env; }
set_env APP_NAME "$name"
set_env APP_DISPLAY_NAME "\"$display_name\""
set_env BUNDLE_ID "$bundle_id"
set_env COPYRIGHT "\"Copyright © $year $holder\""
set_env RELEASES_URL "https://github.com/$repo/releases"
set_env SPARKLE_PUBLIC_KEY ""
set_env TEAM_ID ""

log "reset version to 0.0.0"
echo 0.0.0 >version.txt
printf '{\n  ".": "0.0.0"\n}\n' >.release-please-manifest.json
rm -f CHANGELOG.md

# Deletes the marked template-only blocks, then squeezes the blank lines they leave.
drop_template_blocks() {
    local file=$1 start=$2 end=$3 content
    sed -i '' "/$start/,/$end/d" "$file"
    content=$(cat -s "$file")
    printf '%s\n' "$content" >"$file"
}

log "update LICENSE, README, CODEOWNERS, issue templates"
sed -i '' "s|^Copyright (c) .*|Copyright (c) $year $holder|" LICENSE
sed -i '' "1s|.*|# $display_name|" README.md
drop_template_blocks README.md '<!-- template-only:start -->' '<!-- template-only:end -->'
sed -i '' "s|@[A-Za-z0-9_/-]*|$codeowner|g" .github/CODEOWNERS
sed -i '' "s|github.com/[^/]*/[^/]*/security|github.com/$repo/security|" .github/ISSUE_TEMPLATE/config.yml

log "remove template-only files"
drop_template_blocks Makefile '^# template-only:start' '^# template-only:end'
rm -f docs/TEMPLATE-PLAN.md docs/ACCEPTANCE.md "$ROOT/scripts/init.sh"

cat >&2 <<EOF

Done. Review with \`git diff\`, then commit, for example:
  git add -A && git commit -m "chore: initialize $name from template"

Next:
  1. Replace the icon (Icon Composer, or the brand skill in .claude/skills/brand) and
     the Greeter demo.
  2. make setup && make run
  3. One-time release setup: docs/RELEASING.md (make github-setup, GitHub App,
     make sparkle-keys, optional Developer ID).
EOF
