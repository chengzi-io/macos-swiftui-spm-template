#!/usr/bin/env bash
# Turns this template into the user's own app, once: renames the Xcode project and its
# scheme; writes App/Configs/Identity.xcconfig, LICENSE, CODEOWNERS, the issue template
# link and README.md; strips the template-only blocks; deletes this skill and its
# .claude/skills link; then fails while any template word remains.
#
#   init.sh                          read-only preflight; prints the defaults it can work out
#   init.sh --dry-run --name MyApp   the checks and the plan; changes nothing
#   init.sh --name MyApp [options]   makes the app
#
# Options (each default as printed by init.sh without --name):
#   --name NAME             the app: the .app, the executable, the Xcode project and its
#                           scheme; a capital letter, then letters and digits
#   --about "..."           one sentence on what the app does, for README.md; optional,
#                           the placeholder line stays when it is not given
#   --display-name "My App" APP_DISPLAY_NAME; defaults to NAME
#   --bundle-id com.example.myapp  BUNDLE_ID; defaults to com.<gh login>.<name, lowercase>
#   --category VALUE        APP_CATEGORY; defaults to the current one. VALUE is
#                           public.app-category. plus one of these 40:
#     business, developer-tools, education, entertainment, finance, games, action-games,
#     adventure-games, arcade-games, board-games, card-games, casino-games, dice-games,
#     educational-games, family-games, kids-games, music-games, puzzle-games, racing-games,
#     role-playing-games, simulation-games, sports-games, strategy-games, trivia-games,
#     word-games, graphics-design, healthcare-fitness, lifestyle, medical, music, news,
#     photography, productivity, reference, social-networking, sports, travel, utilities,
#     video, weather
#   --repo owner/repo       GITHUB_REPOSITORY; defaults to the origin remote
#   --codeowner @user       .github/CODEOWNERS; defaults to @<gh login>
#   --copyright "Jane Doe"  the LICENSE holder; defaults to the repository owner
#   --locales "en zh-Hans"  REQUIRED_LOCALES; en is always included
#   --skip-xcode            skip the Xcode check (only to test on a machine without Xcode)
#   --dry-run               print every change as a "would ..." line, then stop
#   -h, --help              this text
#
# TEAM_ID keeps its current value. Each step skips what is already done, so a run that
# stopped can run again with the same arguments. Close the project in Xcode first: it
# writes window state back to the old path.

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../../../../scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../../scripts/common.sh"

# What only the template carries. The last step fails while any of these words remain.
TEMPLATE_NAME=Pomelo
TEMPLATE_REPO=chengzi-io/macos-swiftui-spm-template
LEFTOVERS='setup-project|template-only|Pomelo'
IDENTITY=App/Configs/Identity.xcconfig
SKILL=.agents/skills/setup-project
LINK=.claude/skills/setup-project

# The 40 App Store categories, each after public.app-category.
CATEGORIES="business developer-tools education entertainment finance games action-games
adventure-games arcade-games board-games card-games casino-games dice-games
educational-games family-games kids-games music-games puzzle-games racing-games
role-playing-games simulation-games sports-games strategy-games trivia-games word-games
graphics-design healthcare-fitness lifestyle medical music news photography productivity
reference social-networking sports travel utilities video weather"

name="" about="" display_name="" bundle_id="" category="" repo="" codeowner="" holder=""
locales="" skip_xcode=0 dry_run=0
gh_login=""
errors=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

usage() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0" >&2
    exit "$1"
}

# identity KEY: prints the KEY value Identity.xcconfig has now (common.sh's exports are
# from when the script started).
identity() {
    sed -nE "s/^$1[[:space:]]*=[[:space:]]*(.*[^[:space:]])?[[:space:]]*\$/\\1/p" "$IDENTITY"
}

# --- Inputs -------------------------------------------------------------------------

parse_inputs() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-xcode) skip_xcode=1; shift; continue ;;
            --dry-run) dry_run=1; shift; continue ;;
            -h | --help) usage 0 ;;
        esac
        [[ $# -ge 2 ]] || usage 1
        case $1 in
            --name) name=$2 ;;
            --about) about=$2 ;;
            --display-name) display_name=$2 ;;
            --bundle-id) bundle_id=$2 ;;
            --category) category=$2 ;;
            --repo) repo=$2 ;;
            --codeowner) codeowner=$2 ;;
            --copyright) holder=$2 ;;
            --locales) locales=$2 ;;
            *) usage 1 ;;
        esac
        shift 2
    done
}

# --- Checks -------------------------------------------------------------------------

fail() {
    echo "error: $*" >&2
    errors=$((errors + 1))
}

# preflight: the tools and repository state init needs. Reports every problem.
preflight() {
    local version wanted
    command -v git >/dev/null || fail "git missing"
    if ((skip_xcode == 0)); then
        if ! version=$(xcodebuild -version 2>/dev/null | sed -n 1p); then
            fail "xcodebuild does not run; install Xcode, then: sudo xcode-select -s /Applications/Xcode.app"
        elif [[ -f .xcode-version ]]; then
            wanted=$(tr -d '[:space:]' <.xcode-version)
            [[ $version == "Xcode $wanted" ]] || fail "$version runs, .xcode-version wants Xcode $wanted"
        fi
    fi
    if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
        gh_login=$(gh api user --jq .login 2>/dev/null) || gh_login=""
    fi
    if [[ -z $gh_login && (-z $codeowner || -z $bundle_id) ]]; then
        fail "gh is not signed in (gh auth login); without it, pass --codeowner and --bundle-id"
    fi
    git remote get-url origin >/dev/null 2>&1 || [[ -n $repo ]] ||
        fail "no origin remote; add one or pass --repo owner/repo"
    [[ $VERSION == 0.0.0 ]] || fail "version.txt is $VERSION: this app has shipped, and a new name would make it a different app"
    grep -q '"\.": "0\.0\.0"' .release-please-manifest.json ||
        fail ".release-please-manifest.json is not at 0.0.0"
    [[ -z $(git tag -l 'v*') ]] || fail "release tags exist: this app has shipped"
    # A clean tree keeps the init diff reviewable and undoable. A run that stopped
    # halfway may resume: the identity, and with it the project, carries the new name.
    if [[ -n $(git status --porcelain) ]] && ! resuming; then
        fail "the working tree has changes; commit or stash them first"
    fi
}

resuming() {
    [[ -n $name && $name != "$TEMPLATE_NAME" ]] &&
        [[ $APP_NAME == "$name" ]]
}

# The app's module takes its name: no name the project, its targets or the package
# already use, and no module or framework an app module would shadow.
RESERVED="App AppUITests AppPackage AppModules Scene View Window WindowGroup Text Image
Color Button Label List Form Menu Toggle Commands SwiftUI AppKit Foundation Observation
Combine Swift XCTest Testing OSLog Sparkle"

# package_targets: every target name Package.swift declares (not the package's own name).
package_targets() {
    grep -E '^[[:space:]]+name: "[^"]+",?$' Package.swift | grep -vE '^    name: ' |
        sed -E 's/.*name: "([^"]+)".*/\1/'
    sed -nE 's/.*\.library\(name: "([^"]+)".*/\1/p' Package.swift
}

# is_category VALUE: whether VALUE is one of the 40 App Store categories.
is_category() {
    local value
    for value in $CATEGORIES; do
        [[ $1 != "public.app-category.$value" ]] || return 0
    done
    return 1
}

# default_name: the repository's name in CamelCase (my-cool-app -> MyCoolApp), or nothing
# when it is no app name: every part that is not a letter or a digit starts a word.
default_name() {
    local word out=""
    [[ -n $repo ]] || return 0
    for word in $(printf '%s' "${repo#*/}" | tr -c 'A-Za-z0-9' ' '); do
        out=$out$(printf '%s' "${word:0:1}" | tr '[:lower:]' '[:upper:]')${word:1}
    done
    [[ $out =~ ^[A-Z][A-Za-z0-9]*$ && $out != "$TEMPLATE_NAME" ]] || return 0
    printf '%s' "$out"
}

# resolve_defaults: fills in what the user left out. Call after preflight.
resolve_defaults() {
    local remote lower
    if [[ -z $repo ]] && remote=$(git remote get-url origin 2>/dev/null); then
        repo=$(sed -E 's#^(git@[^:]+:|ssh://[^/]+/|https?://[^/]+/)##; s#\.git$##' <<<"$remote")
    fi
    if [[ -z $name ]]; then
        name=$(default_name)
    fi
    display_name=${display_name:-$name}
    holder=${holder:-${repo%%/*}}
    [[ -n $codeowner || -z $gh_login ]] || codeowner=@$gh_login
    if [[ -z $bundle_id && -n $gh_login && -n $name ]]; then
        lower=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
        bundle_id="com.$(printf '%s' "$gh_login" | tr '[:upper:]' '[:lower:]').$lower"
    fi
    category=${category:-$(identity APP_CATEGORY)}
    locales=${locales:-en}
    locales=$(tr ',' ' ' <<<"$locales" | tr -s ' ' | sed -E 's/^ //; s/ $//')
}

# validate: every rule on the inputs, all reported at once.
validate() {
    local value word found=0 locale
    if [[ -z $name ]]; then
        fail "--name is required"
        return
    fi
    [[ $name =~ ^[A-Z][A-Za-z0-9]*$ ]] ||
        fail "--name $name: a capital letter, then letters and digits; it names the .app, the executable and the package"
    if [[ $name == "$TEMPLATE_NAME" ]]; then
        fail "--name $name is the template's name; pick the app's own"
    elif [[ $name != "$APP_NAME" ]]; then
        for word in $RESERVED; do
            [[ $name != "$word" ]] || found=1
        done
        while read -r word; do
            [[ -z $word || $name != "$word" ]] || found=1
        done < <(package_targets)
        ((found == 0)) || fail "--name $name is reserved: the Xcode project, a package target, SwiftUI or a system module already uses it"
        [[ ! -e App/$name.xcodeproj ]] || fail "App/$name.xcodeproj already exists"
    fi
    [[ $bundle_id =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] ||
        fail "--bundle-id '$bundle_id' must look like com.example.myapp"
    [[ $repo =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || fail "--repo '$repo' must be owner/repo"
    [[ $repo != "$TEMPLATE_REPO" ]] ||
        fail "--repo is the template itself; create the app's repository (Use this template) and pass it"
    [[ $codeowner =~ ^@[A-Za-z0-9-]+(/[A-Za-z0-9._-]+)?$ ]] ||
        fail "--codeowner '$codeowner' must be @user or @org/team"
    is_category "$category" ||
        fail "--category '$category' is not an App Store category; the 40 public.app-category.* values are listed in --help"
    [[ -n $display_name && -n $holder ]] || fail "--display-name and --copyright cannot be empty"
    for value in "$display_name" "$holder" "$about"; do
        [[ $value != *[\"\$\\\`\|\&]* ]] || fail "'$value' cannot contain \" \$ \\ \` | or &"
        # Identity.xcconfig would read the rest of the line as a comment.
        [[ $value != *//* ]] || fail "'$value' cannot contain //"
    done
    [[ $about != *$'\n'* ]] || fail "--about cannot contain a newline"
    if grep -qE "$LEFTOVERS" <<<"$name"; then
        fail "'$name' contains a template word ($LEFTOVERS); the last step would reject it"
    fi
    for value in "$display_name" "$bundle_id" "$repo" "$codeowner" "$holder" "$about"; do
        [[ $value != "$name" ]] || continue
        if grep -qE "$LEFTOVERS" <<<"$value"; then
            fail "'$value' contains a template word ($LEFTOVERS); the last step would reject it"
        fi
    done
    found=0
    for locale in $locales; do
        [[ $locale =~ ^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$ ]] || fail "--locales: '$locale' is not a locale like en or zh-Hans"
        [[ $locale != en ]] || found=1
    done
    ((found == 1)) || fail "--locales must include en, the source language"
}

# print_defaults: every default init can work out, one per line.
print_defaults() {
    local year
    year=$(date +%Y)
    cat <<OUT
name            ${name:-(ask)}
about           (optional)
display-name    ${display_name:-(ask)}
bundle-id       ${bundle_id:-(ask)}
category        ${category:-(ask)}
repo            ${repo:-(ask)}
codeowner       ${codeowner:-(ask)}
copyright       Copyright © $year ${holder:-(ask)}
locales         ${locales:-(ask)}
OUT
}

print_after() {
    cat <<OUT
After setup-project:
  1. make setup && make ci, then commit: chore: initialize $name from template
  2. with the user's consent: git push origin main, then make github-settings
  3. build the app: add-feature (the first feature replaces Notes), macos-recipes, app-icon, dmg
  4. to ship: release-setup
  make status shows where the project stands at any time.
OUT
}

# --- Edits --------------------------------------------------------------------------

# put FILE < content: writes FILE only when the content differs; prints what it did, or
# with --dry-run what it would do.
put() {
    local file=$1
    cat >"$TMP/new"
    if [[ -f $file ]] && cmp -s "$TMP/new" "$file"; then
        echo "   done already: $file" >&2
    elif ((dry_run == 1)); then
        if [[ -f $file ]]; then
            echo "   would edit: $file ($(diff "$file" "$TMP/new" | grep -c '^[<>]' || true) lines)" >&2
        else
            echo "   would create: $file" >&2
        fi
    else
        cat "$TMP/new" >"$file"
        echo "   wrote: $file" >&2
    fi
}

# edit FILE -e expr [-e expr...]: put FILE through `sed -E` (without sed -i, where BSD
# and GNU sed differ). Every expression must still find its target: the left side of an
# s-expression, or the address of /RE/..., must match the file. One that no longer does
# means the template changed under this script, so it dies instead of silently doing
# nothing. Other commands (the n and } of an address block) pass unchecked.
edit() {
    local file=$1 expr delim target
    local -a seds=()
    shift
    [[ -f $file ]] || die "no $file"
    while [[ $# -gt 0 ]]; do
        [[ $1 == -e && -n ${2:-} ]] || die "edit $file: pass sed expressions as -e <expr>"
        expr=$2
        seds+=(-e "$expr")
        shift 2
        case $expr in
            s?*)
                # s<delim>LHS<delim>...: the LHS sits between the first two delimiters.
                delim=${expr:1:1}
                target=${expr#s"$delim"}
                target=${target%%"$delim"*}
                ;;
            /*)
                # /RE/...: the RE sits between the first two slashes.
                target=${expr#/}
                target=${target%%/*}
                ;;
            *) target="" ;;
        esac
        if [[ -n $target ]] && ! grep -qE -- "$target" "$file"; then
            die "edit $file: '$expr' matches nothing; the template changed under it"
        fi
    done
    sed -E "${seds[@]}" "$file" >"$TMP/edited"
    put "$file" <"$TMP/edited"
}

# set_identity KEY value: the KEY line of Identity.xcconfig, appended when missing.
set_identity() {
    if grep -qE "^$1[[:space:]]*=" "$IDENTITY"; then
        if [[ $(identity "$1") == "$2" ]]; then
            echo "   done already: $1 = $2" >&2
            return
        fi
        sed -E -e "s|^$1[[:space:]]*=.*|$1 = $2|" -e 's/[[:space:]]+$//' "$IDENTITY" >"$TMP/identity"
    else
        { cat "$IDENTITY"; echo "$1 = $2"; } >"$TMP/identity"
    fi
    if ((dry_run == 1)); then
        echo "   would set: $1 = $2 ($IDENTITY)" >&2
    else
        cat "$TMP/identity" >"$IDENTITY"
        echo "   set: $1 = $2" >&2
    fi
}

# run description command...: runs it, or with --dry-run says it would.
run() {
    local description=$1
    shift
    if ((dry_run == 1)); then
        echo "   would $description" >&2
    else
        "$@"
        echo "   $description" >&2
    fi
}

# --- Steps --------------------------------------------------------------------------

# rename: the Xcode project and its scheme carry the app's name; the targets inside stay
# App and AppUITests.
rename() {
    local old=$APP_NAME schemes list targets
    log "1/7 rename the Xcode project and its scheme to $name"
    if [[ $old == "$name" ]]; then
        echo "   done already: $XCODE_PROJECT" >&2
        return
    fi
    [[ -f $XCODE_SCHEME ]] || die "no $XCODE_SCHEME"
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
}

identity_step() {
    log "2/7 identity: $IDENTITY"
    set_identity APP_DISPLAY_NAME "$display_name"
    set_identity BUNDLE_ID "$bundle_id"
    set_identity APP_CATEGORY "$category"
    set_identity COPYRIGHT "Copyright © $(date +%Y) $holder"
    set_identity GITHUB_REPOSITORY "$repo"
    set_identity REQUIRED_LOCALES "$locales"
}

licenses() {
    local year
    year=$(date +%Y)
    log "3/7 LICENSE, CODEOWNERS, issue template link"
    edit LICENSE -e "s|^Copyright \(c\) .*|Copyright (c) $year $holder|"
    edit .github/CODEOWNERS -e "s|@[A-Za-z0-9_/.-]+|$codeowner|g"
    edit .github/ISSUE_TEMPLATE/config.yml -e "s|github.com/[^/]+/[^/]+/security|github.com/$repo/security|"
}

readme() {
    local min_macos
    local -a seds=()
    log "4/7 README.md: the page for $display_name's users"
    min_macos=$(sed -nE 's/^MACOSX_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' App/Configs/Project.xcconfig)
    [[ -n $min_macos ]] || die "no MACOSX_DEPLOYMENT_TARGET in App/Configs/Project.xcconfig"
    seds=(-e "s|{{NAME}}|$name|g" -e "s|{{DISPLAY_NAME}}|$display_name|g" -e "s|{{REPO}}|$repo|g"
        -e "s|{{MIN_MACOS}}|$min_macos|g")
    if [[ -n $about ]]; then
        grep -qE '^_What .* does and for whom, in one sentence\._$' "$SKILL_DIR/wiring/README.md" ||
            die "$SKILL_DIR/wiring/README.md has no 'What ... does' line for --about; the template changed under it"
        seds+=(-e "s|^_What .* does and for whom, in one sentence\._$|_${about}_|")
    else
        echo "   README placeholder kept: the sentence at the top of README.md is still to write" >&2
    fi
    sed -E "${seds[@]}" "$SKILL_DIR/wiring/README.md" | put README.md
}

# template_only: the lines from one carrying template-only:start to one carrying
# template-only:end, markers included.
template_only() {
    local blocks file
    log "5/7 template-only blocks"
    blocks=$(git grep -l -I --untracked 'template-only:start' -- . ":(exclude)$SKILL" || true)
    [[ -n $blocks ]] || echo "   done already: no template-only blocks" >&2
    for file in $blocks; do
        # Then squeezes the blank lines a dropped block left.
        sed -E '/template-only:start/,/template-only:end/d' "$file" | cat -s >"$TMP/dropped"
        put "$file" <"$TMP/dropped"
    done
    # Before the skill goes, so a leftover can be fixed and this script run again.
    if ((dry_run == 0)) && git grep -n -I --untracked -E "$LEFTOVERS" -- . ":(exclude)$SKILL" ":(exclude)$LINK"; then
        die "the lines above still carry the template; fix them, then run this again"
    fi
}

delete_skill() {
    log "6/7 this skill: $SKILL and $LINK"
    if [[ -L $LINK || -e $LINK ]]; then
        run "remove $LINK" rm -f "$LINK"
    else
        echo "   done already: $LINK" >&2
    fi
    # Last: bash has already read this script's file.
    if [[ -d $SKILL ]]; then
        run "remove $SKILL" rm -rf "$SKILL"
    else
        echo "   done already: $SKILL" >&2
    fi
}

leftovers() {
    if ((dry_run == 1)); then
        log "7/7 leftovers: would check git grep -n -E '$LEFTOVERS'"
        return
    fi
    # Stage the deletions, as the renames are staged, so git ls-files stops listing them.
    git rm -r -q --cached --ignore-unmatch -- "$LINK" "$SKILL"
    log "7/7 leftovers: git grep -n -E '$LEFTOVERS' (tracked and untracked files)"
    if git grep -n -I --untracked -E "$LEFTOVERS"; then
        die "the lines above still carry the template"
    fi
    log "no template leftovers"
}

# --- Main ---------------------------------------------------------------------------

parse_inputs "$@"

# No --name: the read-only preflight and the defaults.
if [[ -z $name && $dry_run == 0 ]]; then
    preflight
    if ((errors > 0)); then
        echo "init: $errors problem(s); nothing was changed" >&2
        exit 1
    fi
    resolve_defaults
    print_defaults
    exit 0
fi

[[ -n $name ]] || usage 1
preflight
resolve_defaults
validate
if ((errors > 0)); then
    echo "init: $errors problem(s); nothing was changed" >&2
    exit 1
fi
if ((dry_run == 0)); then
    # The tree was clean (or this resumes a run), so git undoes a run that stops halfway.
    trap 'status=$?; rm -rf "$TMP"; ((status == 0)) || echo "error: init stopped halfway; with the user'"'"'s consent, undo it with: git reset --hard && git clean -fd" >&2' EXIT
fi

rename
identity_step
licenses
readme
template_only
delete_skill
leftovers
print_after
