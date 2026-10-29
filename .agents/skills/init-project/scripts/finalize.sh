#!/usr/bin/env bash
# Last step of init: deletes the template-only blocks (AGENTS.md, Makefile, any file that
# has them), this skill and its .claude/skills link, then fails while any of
# init-project, template-only or the template's name remains in the repository.
#
#   finalize.sh [--dry-run]

source "$(dirname "$0")/lib.sh"

case ${1:-} in
    "") ;;
    --dry-run) dry_run=1 ;;
    *) sed -n '2,6p' "$0" | sed -E 's/^# ?//' >&2; exit 1 ;;
esac
[[ $(identity APP_NAME) != "$TEMPLATE_NAME" && $APP_TARGET != "$TEMPLATE_NAME" ]] ||
    die "run apply.sh first: the app is still named $TEMPLATE_NAME"
skill=.agents/skills/init-project
link=.claude/skills/init-project

log "1/3 template-only blocks"
blocks=$(git grep -l -I --untracked 'template-only:start' -- . ":(exclude)$skill" || true)
[[ -n $blocks ]] || echo "   done already: no template-only blocks" >&2
for file in $blocks; do
    # Drops each marked block (both markers included), then squeezes the blank lines it left.
    sed -E '/template-only:start/,/template-only:end/d' "$file" | cat -s >"$TMP/dropped"
    put "$file" <"$TMP/dropped"
done

# Before the skill goes, so a leftover can be fixed and this script run again.
if ((dry_run == 0)) && git grep -n -I --untracked -E "$LEFTOVERS" -- . ":(exclude)$skill" ":(exclude)$link"; then
    die "the lines above still carry the template; fix them (apply.sh, remove-demo.sh or by hand), then run this again"
fi

log "2/3 this skill: $skill and $link"
if [[ -L $link || -e $link ]]; then
    run "remove $link" rm -f "$link"
else
    echo "   done already: $link" >&2
fi
# Last: bash has already read this script's file, and lib.sh is sourced.
if [[ -d $skill ]]; then
    run "remove $skill" rm -rf "$skill"
else
    echo "   done already: $skill" >&2
fi

if ((dry_run == 1)); then
    log "dry run done; nothing was changed"
    exit 0
fi

log "3/3 leftovers: git grep -n -E '$LEFTOVERS' (tracked and untracked files)"
if git grep -n -I --untracked -E "$LEFTOVERS"; then
    die "the lines above still carry the template"
fi
log "finalized: no template leftovers. Confirm: rg -n --hidden -g '!.git' '$LEFTOVERS'"
log "next: make setup && make ci, then git diff HEAD --stat and commit"
