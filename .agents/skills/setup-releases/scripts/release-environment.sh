#!/usr/bin/env bash
# Limits the `release` environment, which holds the release secrets, to protected
# branches: release-please and the publish job run from main. Needs gh with admin rights
# and main protected first (make github-settings). Prints the policy read back.

# shellcheck source=../../../../scripts/common.sh
source "$(dirname "$0")/../../../../scripts/common.sh"

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
gh api "repos/$repo/branches/main/protection" >/dev/null ||
    die "main is not protected on $repo, so no branch could reach the environment; run make github-settings (a private repository needs GitHub Pro or a paid plan for it)"
log "configure the release environment of $repo"

gh api --method PUT "repos/$repo/environments/release" --input - >/dev/null <<'JSON'
{ "deployment_branch_policy": { "protected_branches": true, "custom_branch_policies": false } }
JSON

echo "environment:  $(gh api "repos/$repo/environments/release" --jq .deployment_branch_policy)"

cat >&2 <<EOF

Still manual (setup-releases skill, steps 3 to 5):
  - GitHub App for release-please: variable RELEASE_APP_CLIENT_ID
  - release environment secrets: RELEASE_APP_PRIVATE_KEY, SPARKLE_ED_PRIVATE_KEY, and
    with a Developer ID the DEVELOPER_ID_P12_* and NOTARY_API_* secrets
EOF
