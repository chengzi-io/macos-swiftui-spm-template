#!/usr/bin/env bash
# Makes the template the user's app: renames the Xcode project and its scheme; writes
# App/Configs/Identity.xcconfig (REQUIRED_LOCALES included); LICENSE,
# CODEOWNERS and the issue template link; README.md from wiring/README.md; removes
# docs/assets/icon.* and docs/assets/notes-*.png. Runs check.sh's rules first and stops on any problem.
#
#   apply.sh --dry-run --name MyApp [options]   lists every change, changes nothing
#   apply.sh --name MyApp [options]             makes them
#
# Options are check.sh's (see check.sh --help); pass the args line check.sh printed.
# Each step skips what is already done, so a run that stopped can run again. Renames
# are staged with git mv. Close the project in Xcode first: it writes window state back
# to the old path.

source "$(dirname "$0")/lib.sh"

usage() {
    sed -n '2,13p' "$0" | sed -E 's/^# ?//' >&2
    exit "$1"
}

parse_inputs "$@"
[[ -n $name ]] || usage 1
preflight
resolve_defaults
validate
if ((errors > 0)); then
    echo "apply: $errors problem(s); nothing was changed" >&2
    exit 1
fi

if ((dry_run == 1)); then
    log "dry run: nothing below is changed"
else
    # The tree was clean (or this resumes a run), so git undoes a run that stops halfway.
    trap 'status=$?; rm -rf "$TMP"; ((status == 0)) || echo "error: apply stopped halfway; with the user'"'"'s consent, undo it with: git reset --hard && git clean -fd" >&2' EXIT
fi
year=$(date +%Y)
old=$APP_NAME

log "1/5 rename the Xcode project and its scheme to $name"
if [[ $old == "$name" ]]; then
    echo "   done already: $XCODE_PROJECT" >&2
else
    [[ -f $XCODE_SCHEME ]] || die "no $XCODE_SCHEME"
    # The targets stay App and AppUITests; only the project, the scheme and the product
    # carry the app's name.
    edit "$XCODE_SCHEME" \
        -e "s/BuildableName = \"$old\.app\"/BuildableName = \"$name.app\"/" \
        -e "s/container:$old\.xcodeproj/container:$name.xcodeproj/"
    # The one place the project names itself: a comment Xcode writes when it saves.
    edit "$XCODE_PROJECT/project.pbxproj" -e "s/PBXProject \"$old\"/PBXProject \"$name\"/g"
    schemes=$XCODE_PROJECT/xcshareddata/xcschemes
    run "git mv $XCODE_SCHEME $schemes/$name.xcscheme" git mv "$XCODE_SCHEME" "$schemes/$name.xcscheme"
    run "git mv $XCODE_PROJECT App/$name.xcodeproj" git mv "$XCODE_PROJECT" "App/$name.xcodeproj"
    # Right after the move: the scripts find the project through APP_NAME.
    set_identity APP_NAME "$name"
    if ((dry_run == 0 && skip_xcode == 0)); then
        list=$(xcodebuild -list -json -project "App/$name.xcodeproj")
        targets=$(plutil -extract project.targets json -o - - <<<"$list")
        schemes=$(plutil -extract project.schemes json -o - - <<<"$list")
        [[ $targets == *'"App"'* && $targets == *'"AppUITests"'* && $schemes == *"\"$name\""* ]] ||
            die "App/$name.xcodeproj has targets $targets and schemes $schemes, expected App, AppUITests and $name"
    fi
fi

log "2/5 identity: App/Configs/Identity.xcconfig"
set_identity APP_DISPLAY_NAME "$display_name"
set_identity BUNDLE_ID "$bundle_id"
set_identity COPYRIGHT "Copyright © $year $holder"
set_identity GITHUB_REPOSITORY "$repo"
set_identity TEAM_ID "$team_id"
set_identity REQUIRED_LOCALES "$locales"
# The template's Sparkle key belongs to the template; the release-setup skill makes the app's.
edit App/Configs/Info.plist -e '/<key>SUPublicEDKey<\/key>/{' -e 'n' -e 's|<string>.*</string>|<string></string>|' -e '}'

log "3/5 LICENSE, CODEOWNERS, issue template link"
edit LICENSE -e "s|^Copyright \(c\) .*|Copyright (c) $year $holder|"
edit .github/CODEOWNERS -e "s|@[A-Za-z0-9_/.-]+|$codeowner|g"
edit .github/ISSUE_TEMPLATE/config.yml -e "s|github.com/[^/]+/[^/]+/security|github.com/$repo/security|"

log "4/5 README.md: the page for $display_name's users"
min_macos=$(sed -nE 's/^MACOSX_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' App/Configs/Project.xcconfig)
[[ -n $min_macos ]] || die "no MACOSX_DEPLOYMENT_TARGET in App/Configs/Project.xcconfig"
sed -e "s|{{NAME}}|$name|g" -e "s|{{DISPLAY_NAME}}|$display_name|g" -e "s|{{REPO}}|$repo|g" \
    -e "s|{{MIN_MACOS}}|$min_macos|g" "$SKILL_DIR/wiring/README.md" | put README.md

log "5/5 the template's icon artwork and screenshots in docs/assets"
icons=$(find docs/assets -maxdepth 1 \( -name 'icon.*' -o -name 'notes-*.png' \) 2>/dev/null || true)
if [[ -z $icons ]]; then
    echo "   done already: no docs/assets/icon.* or notes-*.png" >&2
else
    for icon in $icons; do
        run "remove $icon" rm -f "$icon"
    done
fi

if ((dry_run == 1)); then
    log "dry run done; nothing was changed"
else
    log "applied. Next: remove-demo.sh (if the user said so), then finalize.sh"
fi
