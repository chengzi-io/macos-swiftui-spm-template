#!/usr/bin/env bash
# Sets the GitHub repository's settings, then prints them read back. Needs gh signed in
# with admin rights on the repository. Safe to run again: run it after the first push of
# main, and again when a second person gets push access.
#   - squash merge only, the PR title as the commit title (release-please reads it);
#     merged branches are deleted
#   - main protected, admins included: every change arrives by PR, with "Validate PR
#     title", "Lint, test, build" and "Lint scripts and workflows" passed; no force push
#     or deletion; an approving review once two or more people can push
#   - the default workflow token read-only
#   - Dependabot alerts and security updates
#   - private vulnerability reporting, secret scanning and push protection
# A private repository gets no private vulnerability reporting (GitHub offers it on public
# ones only), and its plan may lack branch protection (GitHub Free) or secret scanning:
# each is reported as skipped, with the reason. Any other failure stops the script.
#
#   github-settings.sh

source "$(dirname "$0")/common.sh"

command -v gh >/dev/null || die "gh missing; run: brew install gh"
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner) ||
    die "no GitHub repository for this clone; create it and push main first"
[[ $(gh api "repos/$repo" --jq .permissions.admin) == true ]] ||
    die "gh is signed in without admin rights on $repo; gh auth login as an admin of it"
visibility=$(gh api "repos/$repo" --jq .visibility)
log "configure $repo ($visibility)"
skipped=""

# plan_limited what gh-api-args...: a setting a private repository's plan may lack. There
# a failure is noted as skipped, with GitHub's reason; on a public repository it stops.
plan_limited() {
    local what=$1 error
    shift
    error=$(gh api "$@" 2>&1 >/dev/null) && return
    [[ $visibility != public ]] || die "$what: ${error#gh: }"
    skipped+="$what: ${error#gh: }"$'\n'
}

gh api --method PATCH "repos/$repo" \
    -F allow_squash_merge=true \
    -F allow_merge_commit=false \
    -F allow_rebase_merge=false \
    -f squash_merge_commit_title=PR_TITLE \
    -f squash_merge_commit_message=PR_BODY \
    -F delete_branch_on_merge=true >/dev/null

pushers=$(gh api "repos/$repo/collaborators?per_page=100" --jq '[.[] | select(.permissions.push)] | length')
reviews=$([[ $pushers -ge 2 ]] && echo 1 || echo 0)

# The checks must come from GitHub Actions (app 15368). By name alone, a check no app has
# reported yet, as here right after the first push, passes on a commit status that anyone
# with write access posts through the API.
plan_limited "branch protection" --method PUT "repos/$repo/branches/main/protection" --input - <<JSON
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      { "context": "Validate PR title", "app_id": 15368 },
      { "context": "Lint, test, build", "app_id": 15368 },
      { "context": "Lint scripts and workflows", "app_id": 15368 }
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": $reviews,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON

gh api --method PUT "repos/$repo/actions/permissions/workflow" --input - >/dev/null <<'JSON'
{ "default_workflow_permissions": "read", "can_approve_pull_request_reviews": false }
JSON

# Security updates need the alerts on first.
gh api --method PUT "repos/$repo/vulnerability-alerts" >/dev/null
gh api --method PUT "repos/$repo/automated-security-fixes" >/dev/null
if [[ $visibility == public ]]; then
    gh api --method PUT "repos/$repo/private-vulnerability-reporting" >/dev/null
else
    skipped+="private vulnerability reporting: GitHub offers it on public repositories only"$'\n'
fi
plan_limited "secret scanning" --method PATCH "repos/$repo" --input - <<'JSON'
{
  "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}
JSON

gh api "repos/$repo" --jq '"merge:       squash \(.allow_squash_merge), merge commit \(.allow_merge_commit), rebase \(.allow_rebase_merge), title \(.squash_merge_commit_title), delete branch \(.delete_branch_on_merge)"'
if [[ $skipped != *"branch protection:"* ]]; then
    gh api "repos/$repo/branches/main/protection" --jq '"main:        checks \([.required_status_checks.checks[] | "\(.context) (app \(.app_id))"] | join(", ")); admins included \(.enforce_admins.enabled); reviews \(.required_pull_request_reviews.required_approving_review_count)"'
fi
echo "pushers:     $pushers"
gh api "repos/$repo/actions/permissions/workflow" --jq '"workflow:    token \(.default_workflow_permissions)"'
# 204 while the alerts are on, 404 when they are off.
gh api "repos/$repo/vulnerability-alerts" >/dev/null || die "Dependabot alerts are still off on $repo"
gh api "repos/$repo/automated-security-fixes" --jq '"dependabot:  alerts on, security updates \(.enabled)"'
if [[ $skipped != *"private vulnerability reporting:"* ]]; then
    gh api "repos/$repo/private-vulnerability-reporting" --jq '"reporting:   private vulnerability reporting \(.enabled)"'
fi
if [[ $skipped != *"secret scanning:"* ]]; then
    gh api "repos/$repo" --jq '"secrets:     secret scanning \(.security_and_analysis.secret_scanning.status), push protection \(.security_and_analysis.secret_scanning_push_protection.status)"'
fi
[[ -z $skipped ]] || printf '%s' "$skipped" | sed 's/^/skipped:     /'
