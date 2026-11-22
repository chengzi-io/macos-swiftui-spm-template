#!/usr/bin/env bash
# Turns this template into the user's own app, once: writes App/Configs/Identity.xcconfig,
# the languages in App/Configs/Info.plist, LICENSE and README.md; fails while any template
# word remains; then deletes this skill and its .claude/skills link.
#
#   init.sh                          read-only preflight; prints the defaults it can work out
#   init.sh --dry-run --name MyApp   the checks and the plan; changes nothing
#   init.sh --name MyApp [options]   makes the app
#
# Options (each default as printed by init.sh without --name):
#   --name NAME             the app: the .app, the executable, and APP_NAME
#   --bundle-id io.github.owner.myapp  BUNDLE_ID; defaults to io.github.<repository owner>.<name>,
#                           lowercase
#   --repo owner/repo       GITHUB_REPOSITORY; defaults to the origin remote
#   --locales "en zh-Hans"  CFBundleLocalizations; en is always included
#   --skip-xcode            skip the Xcode check (only to test on a machine without Xcode)
#   --dry-run               print every change as a "would ..." line, then stop
#   -h, --help              this text
#
# TEAM_ID keeps its current value. Each step skips what is already done, so a run that
# stopped can run again with the same arguments.

# shellcheck source=../../../../scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../../scripts/common.sh"

# What only the template carries. The last step fails while any of these words remain.
TEMPLATE_NAME=Pomelo
TEMPLATE_REPO=chengzi-io/macos-swiftui-spm-template
# A line only the template's own README.md carries: readme() replaces that page, and
# leaves any other alone.
TEMPLATE_README='built for coding agents'
LEFTOVERS='setup-project|Pomelo'
IDENTITY=App/Configs/Identity.xcconfig
INFO_PLIST=App/Configs/Info.plist
SKILL=.agents/skills/setup-project
LINK=.claude/skills/setup-project

name="" bundle_id="" repo=""
locales="" skip_xcode=0 dry_run=0
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
        --skip-xcode)
            skip_xcode=1
            shift
            continue
            ;;
        --dry-run)
            dry_run=1
            shift
            continue
            ;;
        -h | --help) usage 0 ;;
        esac
        [[ $# -ge 2 ]] || usage 1
        case $1 in
        --name) name=$2 ;;
        --bundle-id) bundle_id=$2 ;;
        --repo) repo=$2 ;;
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
    local version wanted tag
    command -v git >/dev/null || fail "git missing"
    if ((skip_xcode == 0)); then
        if ! version=$(xcodebuild -version 2>/dev/null | sed -n 1p); then
            fail "xcodebuild does not run; install Xcode, then: sudo xcode-select -s /Applications/Xcode.app"
        elif [[ -f .xcode-version ]]; then
            wanted=$(tr -d '[:space:]' <.xcode-version)
            [[ $version == "Xcode $wanted" ]] || fail "$version runs, .xcode-version wants Xcode $wanted"
        fi
    fi
    git remote get-url origin >/dev/null 2>&1 || [[ -n $repo ]] ||
        fail "no origin remote; add one or pass --repo owner/repo"
    # A vX.Y.Z tag means the app has shipped: a new name or bundle id would make it a
    # different app to macOS, Sparkle and Homebrew.
    tag=$(git tag --sort=-v:refname -l 'v[0-9]*.[0-9]*.[0-9]*' | head -1)
    [[ -z $tag ]] || fail "release tag $tag exists: this app has shipped, and a new name would make it a different app"
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
    local remote
    if [[ -z $repo ]] && remote=$(git remote get-url origin 2>/dev/null); then
        repo=$(sed -E 's#^(git@[^:]+:|ssh://[^/]+/|https?://[^/]+/)##; s#\.git$##' <<<"$remote")
    fi
    if [[ -z $name ]]; then
        name=$(default_name)
    fi
    # The repository owner holds <owner>.github.io, so the id is theirs, whoever runs this.
    if [[ -z $bundle_id && -n $repo && -n $name ]]; then
        bundle_id=$(printf 'io.github.%s.%s' "${repo%%/*}" "$name" | tr '[:upper:]' '[:lower:]')
    fi
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
        ((found == 0)) || fail "--name $name is reserved: a package target, SwiftUI or a system module already uses it"
    fi
    [[ $bundle_id =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] ||
        fail "--bundle-id '$bundle_id' must look like com.example.myapp"
    [[ $repo =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || fail "--repo '$repo' must be owner/repo"
    [[ $repo != "$TEMPLATE_REPO" ]] ||
        fail "--repo is the template itself; create the app's repository (Use this template) and pass it"
    if grep -qE "$LEFTOVERS" <<<"$name"; then
        fail "'$name' contains a template word ($LEFTOVERS); the last step would reject it"
    fi
    for value in "$bundle_id" "$repo"; do
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
    cat <<OUT
name            ${name:-(ask)}  (permanent after the first release)
bundle-id       ${bundle_id:-(ask)}  (permanent after the first release)
repo            ${repo:-(ask)}
locales         ${locales:-(ask)}
OUT
}

print_after() {
    cat <<OUT
After setup-project:
  1. make setup && make ci, then commit: chore: initialize $name from template
  2. with the user's consent: git push origin main, then make github-settings
  3. run make status: its first todo line is what comes next (the first feature, the
     icon, the DMG window, releases), one step at a time
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
        {
            cat "$IDENTITY"
            echo "$1 = $2"
        } >"$TMP/identity"
    fi
    if ((dry_run == 1)); then
        echo "   would set: $1 = $2 ($IDENTITY)" >&2
    else
        cat "$TMP/identity" >"$IDENTITY"
        echo "   set: $1 = $2" >&2
    fi
}

# set_locales <space separated>: CFBundleLocalizations, the array macOS reads and make lint
# checks translations against. plutil rewrites the file's indentation only.
set_locales() {
    local json current
    local -a list
    read -r -a list <<<"$1"
    json=$(printf '"%s",' "${list[@]+"${list[@]}"}")
    json="[${json%,}]"
    current=$(plutil -extract CFBundleLocalizations json -o - "$INFO_PLIST" | tr -d '[:space:]') ||
        die "$INFO_PLIST has no CFBundleLocalizations array"
    if [[ $current == "$json" ]]; then
        echo "   done already: CFBundleLocalizations = $1" >&2
        return
    fi
    if ((dry_run == 1)); then
        echo "   would set: CFBundleLocalizations = $1 ($INFO_PLIST)" >&2
    else
        plutil -replace CFBundleLocalizations -json "$json" "$INFO_PLIST"
        echo "   set: CFBundleLocalizations = $1 ($INFO_PLIST)" >&2
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

identity_step() {
    log "1/5 identity: $IDENTITY"
    set_identity APP_NAME "$name"
    set_identity APP_DISPLAY_NAME "$name"
    set_identity BUNDLE_ID "$bundle_id"
    set_identity GITHUB_REPOSITORY "$repo"
    set_locales "$locales"
}

license() {
    local year
    year=$(date +%Y)
    log "2/5 LICENSE"
    edit LICENSE -e "s|^Copyright \(c\) .*|Copyright (c) $year ${repo%%/*}|"
}

# readme: the app's page is its author's to write: the template's page is for people
# choosing the template, so it becomes a stub. A page that is no longer the template's is
# left alone, which is what keeps a second run from overwriting it.
readme() {
    log "3/5 README.md"
    if ! grep -qF "$TEMPLATE_README" README.md; then
        echo "   left alone: README.md is not the template's page" >&2
        return
    fi
    printf '# %s\n\n_What %s does and for whom, in one sentence._\n' "$name" "$name" | put README.md
}

delete_skill() {
    log "5/5 this skill: $SKILL and $LINK"
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

# leftovers: no line of the template is left, which is what lets the skill go: the grep
# runs first, so a hit can be fixed and this script run again.
leftovers() {
    if ((dry_run == 1)); then
        log "4/5 leftovers: would check git grep -n -E '$LEFTOVERS'"
        return
    fi
    # Stage the deletions so git ls-files stops listing them.
    git rm -r -q --cached --ignore-unmatch -- "$LINK" "$SKILL"
    log "4/5 leftovers: git grep -n -E '$LEFTOVERS' (tracked and untracked files)"
    if git grep -n -I --untracked -E "$LEFTOVERS" -- . ":(exclude)$SKILL" ":(exclude)$LINK"; then
        die "the lines above still carry the template; fix them, then run this again"
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

identity_step
license
readme
leftovers
delete_skill
print_after
