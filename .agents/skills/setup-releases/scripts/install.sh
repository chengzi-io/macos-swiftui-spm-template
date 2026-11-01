#!/usr/bin/env bash
# Installs this app's release pipeline from the setup-releases skill: copies every file
# under wiring/ to the same path in the app, and inserts the Install and Update sections
# into README.md. Reads the app's identity from App/Configs/Identity.xcconfig.
#
#   install.sh              install the pipeline; a file that differs stops it
#   install.sh --dry-run    print every change as a "would ..." line, then stop
#   -h, --help              this text
#
# Every wiring file is checked before the first copy, so a run either changes every
# file or none. A file that already matches says "done already", so a run that stopped
# can run again. Prints what comes next in SKILL.md.

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../../../../scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../../scripts/common.sh"

dry_run=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

usage() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0" >&2
    exit "$1"
}

# --- The wiring files ---------------------------------------------------------------

# plan: checks every wiring file and writes "<state> <target>" lines to $TMP/plan. A
# target that differs from its wiring file stops here, before anything is copied.
plan() {
    local file target state
    while IFS= read -r file; do
        target=${file#"$SKILL_DIR/wiring/"}
        if [[ ! -f $target ]]; then
            state=copy
        elif cmp -s "$file" "$target"; then
            state=same
        else
            diff -u "$target" "$file" >&2 || true
            die "$target differs from the skill's wiring; merge by hand, then run this again"
        fi
        printf '%s\t%s\n' "$state" "$target" >>"$TMP/plan"
    done < <(find "$SKILL_DIR/wiring" -type f | sort)
}

apply() {
    local state target
    while IFS=$'\t' read -r state target; do
        if [[ $state == same ]]; then
            echo "   done already: $target" >&2
        elif ((dry_run == 1)); then
            echo "   would copy: $target" >&2
        else
            mkdir -p "$(dirname "$target")"
            cp "$SKILL_DIR/wiring/$target" "$target"
            if [[ -x $SKILL_DIR/wiring/$target ]]; then chmod 755 "$target"; else chmod 644 "$target"; fi
            echo "   wrote: $target" >&2
        fi
    done <"$TMP/plan"
}

# --- README.md ----------------------------------------------------------------------

# fragment: README-install.md with the app's identity filled in, in $TMP/fragment.
fragment() {
    local file=$SKILL_DIR/wiring-fragments/README-install.md min_macos placeholder
    [[ -f $file ]] || die "no $file"
    for placeholder in '{{DISPLAY_NAME}}' '{{REPO}}' '{{MIN_MACOS}}'; do
        grep -qF -- "$placeholder" "$file" || die "$file has no $placeholder; the skill changed under this script"
    done
    min_macos=$(sed -nE 's/^MACOSX_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' App/Configs/Project.xcconfig)
    [[ -n $min_macos ]] || die "no MACOSX_DEPLOYMENT_TARGET in App/Configs/Project.xcconfig"
    sed -E -e "s|\{\{DISPLAY_NAME\}\}|$APP_DISPLAY_NAME|g" \
        -e "s|\{\{REPO\}\}|$GITHUB_REPOSITORY|g" \
        -e "s|\{\{MIN_MACOS\}\}|$min_macos|g" "$file" >"$TMP/fragment"
}

# readme: the Install and Update sections, before README.md's "## Feedback".
readme() {
    local first
    [[ -f README.md ]] || die "no README.md in $PWD"
    first=$(sed -n 1p "$SKILL_DIR/wiring-fragments/README-install.md")
    if grep -qxF -- "$first" README.md; then
        echo "   done already: README.md ($first)" >&2
        return
    fi
    grep -qxF -- '## Feedback' README.md ||
        die "README.md has no '## Feedback' line to put the Install and Update sections before; add it, then run this again"
    fragment
    if ((dry_run == 1)); then
        echo "   would edit: README.md (+$(wc -l <"$TMP/fragment" | tr -d ' ') lines before '## Feedback')" >&2
        return
    fi
    awk -v fragment="$TMP/fragment" '
        $0 == "## Feedback" { while ((getline line < fragment) > 0) print line; print "" }
        { print }
    ' README.md >"$TMP/readme"
    cat "$TMP/readme" >README.md
    echo "   wrote: README.md" >&2
}

print_after() {
    local skill=.agents/skills/setup-releases
    cat >&2 <<EOF

After the install (SKILL.md steps):
  2. release environment: $skill/scripts/release-environment.sh
  3. GitHub App for release-please: xcrun swift $skill/scripts/create-app.swift
  4. Sparkle key: $skill/scripts/sparkle-keys.sh create (or restore FILE)
  5. signing: ad-hoc by default, or the setup-developer-id skill
  6. first release: merge a feat: or fix: PR, then merge release-please's PR
scripts/release-status.sh, or make status, reports what is still todo.
EOF
}

# --- Main ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) dry_run=1 ;;
        -h | --help) usage 0 ;;
        *) usage 1 ;;
    esac
    shift
done

log "install the release pipeline into $PWD"
plan
apply
readme
print_after
