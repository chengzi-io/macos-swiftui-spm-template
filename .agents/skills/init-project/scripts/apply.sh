#!/usr/bin/env bash
# Makes the template the user's app: renames the package, Xcode project, targets and
# scheme; writes App/Configs/Identity.xcconfig (REQUIRED_LOCALES included); LICENSE,
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
old=$APP_TARGET

log "1/5 rename the package, Xcode project, targets and scheme to $name"
if [[ $old == "$name" ]]; then
    echo "   done already: App/$name.xcodeproj" >&2
else
    schemes=$XCODE_PROJECT/xcshareddata/xcschemes
    [[ -f $schemes/$old.xcscheme ]] || die "no $schemes/$old.xcscheme"
    grep -qx "    name: \"$old\"," Package.swift || die "Package.swift does not name the package $old"
    edit "$XCODE_PROJECT/project.pbxproj" \
        -e "s/(remoteInfo|path|name|productName) = $old(UITests)?(\.app|\.xctest)?;/\1 = $name\2\3;/" \
        -e "s#/\* $old(UITests)?(\.app|\.xctest)? \*/#/* $name\1\2 */#g" \
        -e "s/(PBXNativeTarget|PBXProject) \"$old(UITests)?\"/\1 \"$name\2\"/g"
    # Every scheme points into the project; BuildableName is the product, named by APP_NAME.
    for scheme in "$schemes"/*.xcscheme; do
        edit "$scheme" \
            -e "s/BlueprintName = \"$old(UITests)?\"/BlueprintName = \"$name\1\"/" \
            -e "s/BuildableName = \"${old}UITests\.xctest\"/BuildableName = \"${name}UITests.xctest\"/" \
            -e "s/BuildableName = \"$APP_NAME\.app\"/BuildableName = \"$name.app\"/" \
            -e "s/container:$old\.xcodeproj/container:$name.xcodeproj/"
    done
    edit App/Configs/UITests.xcconfig -e "s/^TEST_TARGET_NAME = $old\$/TEST_TARGET_NAME = $name/"
    edit Package.swift -e "s/^    name: \"$old\",\$/    name: \"$name\",/"
    run "git mv $schemes/$old.xcscheme $schemes/$name.xcscheme" git mv "$schemes/$old.xcscheme" "$schemes/$name.xcscheme"
    run "git mv $XCODE_PROJECT App/$name.xcodeproj" git mv "$XCODE_PROJECT" "App/$name.xcodeproj"
    if ((dry_run == 0)); then
        grep -qx "TEST_TARGET_NAME = $name" App/Configs/UITests.xcconfig || die "TEST_TARGET_NAME in App/Configs/UITests.xcconfig is not $name"
        grep -qx "    name: \"$name\"," Package.swift || die "Package.swift does not name the package $name"
        grep -qF "name = $name; path = ..;" "App/$name.xcodeproj/project.pbxproj" || die "App/$name.xcodeproj does not reference the package as $name"
        if ((skip_xcode == 0)); then
            targets=$(xcodebuild -list -json -project "App/$name.xcodeproj" | plutil -extract project.targets json -o - -)
            [[ $targets == *"\"$name\""* && $targets == *"\"${name}UITests\""* ]] ||
                die "App/$name.xcodeproj has targets $targets, expected $name and ${name}UITests"
        fi
    fi
fi

log "2/5 identity: App/Configs/Identity.xcconfig"
set_identity APP_NAME "$name"
set_identity APP_DISPLAY_NAME "$display_name"
set_identity BUNDLE_ID "$bundle_id"
set_identity COPYRIGHT "Copyright © $year $holder"
set_identity GITHUB_REPOSITORY "$repo"
set_identity TEAM_ID "$team_id"
set_identity REQUIRED_LOCALES "$locales"
# The template's Sparkle key belongs to the template; make sparkle-keys makes the app's.
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
