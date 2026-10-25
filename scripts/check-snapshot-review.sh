#!/usr/bin/env bash
# Pull request check: fails while the PR changes view snapshot references
# (__Snapshots__/) and lacks the snapshots-reviewed label. The reviewer adds the label
# after comparing old and new images in the PR's Files changed tab; any later push
# removes it while the PR changes references. Runs on Linux, so it does not source
# common.sh.
#   Reads PR, BASE, HEAD, ACTION, LABELS (JSON array) and GH_TOKEN.
set -euo pipefail

label=snapshots-reviewed
snapshots=':(glob)**/__Snapshots__/**'

changed=$(git diff --name-only "$BASE...$HEAD" -- "$snapshots")
if [[ -z $changed ]]; then
    echo "no snapshot references changed"
    exit 0
fi
echo "changed snapshot references:"
echo "$changed"

reviewed=$(jq -r --arg label "$label" 'index($label) != null' <<<"$LABELS")
# The label covers the commit it was added on, whatever a later push changed: the run
# for an earlier push may not have removed it yet, and a fork's read-only token cannot.
if [[ $ACTION == synchronize ]]; then
    if [[ $reviewed == true ]]; then
        gh pr edit "$PR" --remove-label "$label" ||
            echo "::warning::could not remove $label; remove it, compare the images and add it again"
    fi
    reviewed=false
fi

if [[ $reviewed != true ]]; then
    echo "::error::Snapshot references changed. Compare old and new images in Files changed, then add the $label label."
    exit 1
fi
echo "$label is set"
