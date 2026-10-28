#!/usr/bin/env bash
# One-time GitHub settings for this repository (needs `gh` with admin rights):
#   - squash merge only, commit title = PR title (release-please reads it)
#   - main protected: PR required, "Validate PR title", "Lint, test, build" and
#     "Snapshot review" required, no force push or deletion; reviews required only with
#     two or more pushers
#   - the snapshots-reviewed label, which the Snapshot review check waits for
#   - default workflow token read-only
#   - `release` environment limited to protected branches (release-please and the publish
#     job)
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

gh label create snapshots-reviewed --color 0E8A16 --force \
    --description "Changed view snapshots were compared and accepted" >/dev/null

pushers=$(gh api "repos/$repo/collaborators?per_page=100" --jq '[.[] | select(.permissions.push)] | length')
reviews=$([[ $pushers -ge 2 ]] && echo 1 || echo 0)

# The checks must come from GitHub Actions (app 15368). By name alone, a check no app has
# reported yet, as here right after the first push, passes on a commit status that anyone
# with write access posts through the API.
gh api --method PUT "repos/$repo/branches/$branch/protection" --input - >/dev/null <<JSON
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      { "context": "Validate PR title", "app_id": 15368 },
      { "context": "Lint, test, build", "app_id": 15368 },
      { "context": "Snapshot review", "app_id": 15368 }
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

gh api --method PUT "repos/$repo/environments/release" --input - >/dev/null <<'JSON'
{ "deployment_branch_policy": { "protected_branches": true, "custom_branch_policies": false } }
JSON

gh api --method PUT "repos/$repo/private-vulnerability-reporting" >/dev/null

echo "merge:        $(gh api "repos/$repo" --jq '{squash: .allow_squash_merge, merge: .allow_merge_commit, rebase: .allow_rebase_merge, title: .squash_merge_commit_title}')"
echo "checks:       $(gh api "repos/$repo/branches/$branch/protection" --jq '[.required_status_checks.checks[] | "\(.context) (app \(.app_id))"]')"
echo "reviews:      $reviews (pushers: $pushers)"
echo "workflow:     $(gh api "repos/$repo/actions/permissions/workflow" --jq .default_workflow_permissions)"
echo "environment:  $(gh api "repos/$repo/environments/release" --jq .deployment_branch_policy)"

cat >&2 <<EOF

Still manual (see docs/RELEASING.md):
  - GitHub App for release-please: variable RELEASE_APP_CLIENT_ID
  - release environment secrets: RELEASE_APP_PRIVATE_KEY, SPARKLE_ED_PRIVATE_KEY, and
    with a Developer ID the DEVELOPER_ID_P12_* and NOTARY_API_* secrets
EOF
