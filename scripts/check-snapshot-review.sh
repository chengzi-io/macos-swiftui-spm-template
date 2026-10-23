#!/usr/bin/env bash
# Pull request check: fails while the PR changes view snapshot references
# (__Snapshots__/) and lacks the snapshots-reviewed label. The reviewer adds the label
# after comparing old and new images in the PR's Files changed tab; a later push that
# changes references again removes it. Runs on Linux, so it does not source common.sh.
#   Reads PR, BASE, HEAD, ACTION, BEFORE, AFTER, LABELS (JSON array) and GH_TOKEN.
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
if [[ $ACTION == synchronize && $reviewed == true ]]; then
    # A force push can drop BEFORE from the history; then nothing proves the push left
    # the references alone.
    if ! git cat-file -e "$BEFORE^{commit}" 2>/dev/null ||
        [[ -n $(git diff --name-only "$BEFORE" "$AFTER" -- "$snapshots") ]]; then
        gh pr edit "$PR" --remove-label "$label"
        reviewed=false
        echo "snapshot references changed after the review: removed $label"
    fi
fi

if [[ $reviewed != true ]]; then
    echo "::error::Snapshot references changed. Compare old and new images in Files changed, then add the $label label."
    exit 1
fi
echo "$label is set"
