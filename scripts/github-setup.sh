#!/usr/bin/env bash
# One-time GitHub settings for this repository (needs `gh` with admin rights):
#   - squash merge only, commit title = PR title (release-please reads it)
#   - main protected: PR required, "Validate PR title" + "Lint, test, build" required,
#     no force push or deletion; reviews required only with two or more pushers
#   - default workflow token read-only
#   - `release` environment limited to protected branches (the publish job)
#   - private vulnerability reporting on
# Prints the settings read back from the API.

source "$(dirname "$0")/common.sh"

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
branch=main
log "configure $repo"

gh api --method PATCH "repos/$repo" \
    -F allow_squash_merge=true \
    -F allow_merge_commit=false \
    -F allow_rebase_merge=false \
    -f squash_merge_commit_title=PR_TITLE \
    -f squash_merge_commit_message=PR_BODY \
    -F delete_branch_on_merge=true >/dev/null

pushers=$(gh api "repos/$repo/collaborators?per_page=100" --jq '[.[] | select(.permissions.push)] | length')
reviews=$([[ $pushers -ge 2 ]] && echo 1 || echo 0)

gh api --method PUT "repos/$repo/branches/$branch/protection" --input - >/dev/null <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Validate PR title", "Lint, test, build"]
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

gh api --method PUT "repos/$repo/environments/release" --input - >/dev/null <<'JSON'
{ "deployment_branch_policy": { "protected_branches": true, "custom_branch_policies": false } }
JSON

gh api --method PUT "repos/$repo/private-vulnerability-reporting" >/dev/null

echo "merge:        $(gh api "repos/$repo" --jq '{squash: .allow_squash_merge, merge: .allow_merge_commit, rebase: .allow_rebase_merge, title: .squash_merge_commit_title}')"
echo "checks:       $(gh api "repos/$repo/branches/$branch/protection" --jq '.required_status_checks.contexts')"
echo "reviews:      $reviews (pushers: $pushers)"
echo "workflow:     $(gh api "repos/$repo/actions/permissions/workflow" --jq .default_workflow_permissions)"
echo "environment:  $(gh api "repos/$repo/environments/release" --jq .deployment_branch_policy)"

cat >&2 <<EOF

Still manual (see docs/RELEASING.md):
  - GitHub App for release-please: variable RELEASE_APP_CLIENT_ID, secret RELEASE_APP_PRIVATE_KEY
  - release environment secrets: SPARKLE_ED_PRIVATE_KEY, and with a Developer ID the
    DEVELOPER_ID_P12_* and NOTARY_API_* secrets
EOF
