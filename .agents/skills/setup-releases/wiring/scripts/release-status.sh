#!/usr/bin/env bash
# Reports which steps of the release setup are done, reading only: the pipeline files,
# the repository settings and branch protection (needs gh with admin rights), the
# release-please App's variable and the `release` environment's secret names, the
# Sparkle public key and TEAM_ID. Prints one "ok" or "todo" line per step of
# SKILL.md and exits 0; a secret's value is never read.

source "$(dirname "$0")/common.sh"

skill=.agents/skills/setup-releases

command -v gh >/dev/null || die "gh missing; run: brew install gh"
gh auth status >/dev/null 2>&1 || die "gh not logged in; run: gh auth login"
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
[[ $repo == "$GITHUB_REPOSITORY" ]] ||
    log "gh points at $repo, App/Configs/Identity.xcconfig at $GITHUB_REPOSITORY"

report() {
    if [[ $2 == ok ]]; then echo "ok    $1"; else echo "todo  $1: $3"; fi
}

has() {
    grep -qxF -- "$1" <<<"$2" && echo ok || echo todo
}

# installed: the first wiring file the app lacks or holds differently, or nothing.
installed() {
    local file target
    [[ -d $skill/wiring ]] || {
        echo "$skill/wiring"
        return 0
    }
    while IFS= read -r file; do
        target=${file#"$skill/wiring/"}
        if [[ ! -f $target ]] || ! cmp -s "$file" "$target"; then
            echo "$target"
            return 0
        fi
    done < <(find "$skill/wiring" -type f | sort)
}

squash=$(gh api "repos/$repo" --jq '.allow_squash_merge and (.allow_merge_commit | not) and (.allow_rebase_merge | not)')
protected=$(gh api "repos/$repo/branches/main/protection" --jq '.enforce_admins.enabled' 2>/dev/null || echo false)
environment=$(gh api "repos/$repo/environments/release" --jq '.deployment_branch_policy.protected_branches' 2>/dev/null || echo false)
if [[ $squash == true && $protected == true ]]; then
    report "0 repository settings" ok
else
    report "0 repository settings" todo "make github-settings"
fi

missing=$(installed)
if [[ -z $missing ]]; then
    report "1 pipeline installed" ok
else
    report "1 pipeline installed" todo "$missing is missing or differs; run $skill/scripts/install.sh"
fi
if [[ $environment == true ]]; then
    report "2 release environment" ok
else
    report "2 release environment" todo "run $skill/scripts/release-environment.sh"
fi

variables=$(gh variable list --json name --jq '.[].name')
secrets=$(gh secret list --env release --json name --jq '.[].name' 2>/dev/null || true)
report "3 release-please App: variable RELEASE_APP_CLIENT_ID" "$(has RELEASE_APP_CLIENT_ID "$variables")" "SKILL.md step 3"
report "3 release-please App: secret RELEASE_APP_PRIVATE_KEY" "$(has RELEASE_APP_PRIVATE_KEY "$secrets")" "SKILL.md step 3"

if [[ -n $(plutil -extract SUPublicEDKey raw App/Configs/Info.plist 2>/dev/null) ]]; then
    report "4 Sparkle: SUPublicEDKey in App/Configs/Info.plist" ok
else
    report "4 Sparkle: SUPublicEDKey in App/Configs/Info.plist" todo "run $skill/scripts/sparkle-keys.sh create"
fi
report "4 Sparkle: secret SPARKLE_ED_PRIVATE_KEY" "$(has SPARKLE_ED_PRIVATE_KEY "$secrets")" "SKILL.md step 4"

if [[ -z ${TEAM_ID:-} ]]; then
    echo "info  5 Developer ID: none (TEAM_ID empty), releases are ad-hoc signed"
else
    for secret in DEVELOPER_ID_P12_BASE64 DEVELOPER_ID_P12_PASSWORD NOTARY_API_KEY_P8_BASE64 NOTARY_API_KEY_ID NOTARY_API_ISSUER_ID; do
        report "5 Developer ID: secret $secret" "$(has "$secret" "$secrets")" "the setup-developer-id skill"
    done
fi
