# Sourced by the init-project scripts: the template's identity, the inputs, and the one
# set of rules that check.sh reports and apply.sh enforces.
# macOS ships bash 3.2: no associative arrays, no mapfile, no ${var,,}, guard empty arrays.
# shellcheck shell=bash disable=SC2034 # the scripts that source this file read its variables

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../../../../scripts/common.sh
source "$SKILL_DIR/../../../scripts/common.sh"

# What only the template carries. finalize.sh fails while any of these words remain.
TEMPLATE_NAME=Pomelo
TEMPLATE_REPO=chengzi-io/macos-swiftui-spm-template
LEFTOVERS='init-project|template-only|Pomelo'
IDENTITY=App/Configs/Identity.xcconfig

# identity KEY: prints the KEY value Identity.xcconfig has now (common.sh's exports are
# from when the script started).
identity() {
    sed -nE "s/^$1[[:space:]]*=[[:space:]]*(.*[^[:space:]])?[[:space:]]*\$/\\1/p" "$IDENTITY"
}

# --- Inputs -------------------------------------------------------------------------

name="" display_name="" bundle_id="" repo="" codeowner="" holder="" team_id="" locales=""
team_id_set=0 skip_xcode=0 dry_run=0

# parse_inputs "$@": the flags check.sh and apply.sh share; --dry-run only for apply.sh.
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
            --display-name) display_name=$2 ;;
            --bundle-id) bundle_id=$2 ;;
            --repo) repo=$2 ;;
            --codeowner) codeowner=$2 ;;
            --copyright) holder=$2 ;;
            --team-id) team_id=$2; team_id_set=1 ;;
            --locales) locales=$2 ;;
            *) usage 1 ;;
        esac
        shift 2
    done
}

# --- Checks -------------------------------------------------------------------------

errors=0
fail() {
    echo "error: $*" >&2
    errors=$((errors + 1))
}

gh_login=""
# preflight: the tools and repository state init needs. Reports every problem.
preflight() {
    local version wanted
    command -v git >/dev/null || fail "git missing"
    command -v jq >/dev/null || fail "jq missing (ships with macOS 15+); run: brew install jq"
    if ((skip_xcode == 0)); then
        if ! version=$(xcodebuild -version 2>/dev/null | head -n 1); then
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
    # halfway may resume: the project or the identity already carries the new name.
    if [[ -n $(git status --porcelain) ]] && ! resuming; then
        fail "the working tree has changes; commit or stash them first"
    fi
}

resuming() {
    [[ -n $name && $name != "$TEMPLATE_NAME" ]] &&
        [[ $APP_TARGET == "$name" || $(identity APP_NAME) == "$name" ]]
}

# The names the Xcode project already uses: renaming the targets rewrites them in
# project.pbxproj. Then module and framework names an app module would shadow.
RESERVED="Application AppModules AppStore AppStoreModules Configs Debug Frameworks Products
Release Resources Sources Tests UITests App Settings Notes Scene View Window WindowGroup
Text Image Color Button Label List Form Menu Toggle Commands SwiftUI AppKit Foundation
Observation Combine Swift XCTest Testing OSLog Sparkle"

# package_targets: every target name Package.swift declares (not the package's own name).
package_targets() {
    grep -E '^[[:space:]]+name: "[^"]+",?$' Package.swift | grep -vE '^    name: ' |
        sed -E 's/.*name: "([^"]+)".*/\1/'
    sed -nE 's/.*\.library\(name: "([^"]+)".*/\1/p' Package.swift
}

# resolve_defaults: fills in what the user left out. Call after preflight.
resolve_defaults() {
    local remote lower
    if [[ -z $repo ]] && remote=$(git remote get-url origin 2>/dev/null); then
        repo=$(sed -E 's#^(git@[^:]+:|ssh://[^/]+/|https?://[^/]+/)##; s#\.git$##' <<<"$remote")
    fi
    display_name=${display_name:-$name}
    holder=${holder:-${repo%%/*}}
    [[ -n $codeowner || -z $gh_login ]] || codeowner=@$gh_login
    if [[ -z $bundle_id && -n $gh_login && -n $name ]]; then
        lower=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
        bundle_id="com.$(printf '%s' "$gh_login" | tr '[:upper:]' '[:lower:]').$lower"
    fi
    ((team_id_set == 1)) || team_id=$(identity TEAM_ID)
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
    elif [[ $name != "$APP_TARGET" ]]; then
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
    [[ -z $team_id || $team_id =~ ^[A-Z0-9]{10}$ ]] || fail "--team-id '$team_id' must be 10 capitals and digits, or empty"
    for value in "$display_name" "$holder"; do
        [[ -n $value ]] || fail "--display-name and --copyright cannot be empty"
        [[ $value != *[\"\$\\\`\|\&]* ]] || fail "'$value' cannot contain \" \$ \\ \` | or &"
        # Identity.xcconfig would read the rest of the line as a comment.
        [[ $value != *//* ]] || fail "'$value' cannot contain //"
    done
    if grep -qE "$LEFTOVERS" <<<"$name"; then
        fail "'$name' contains a template word ($LEFTOVERS); finalize.sh would reject it"
    fi
    for value in "$display_name" "$bundle_id" "$repo" "$codeowner" "$holder"; do
        [[ $value != "$name" ]] || continue
        if grep -qE "$LEFTOVERS" <<<"$value"; then
            fail "'$value' contains a template word ($LEFTOVERS); finalize.sh would reject it"
        fi
    done
    found=0
    for locale in $locales; do
        [[ $locale =~ ^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$ ]] || fail "--locales: '$locale' is not a locale like en or zh-Hans"
        [[ $locale != en ]] || found=1
    done
    ((found == 1)) || fail "--locales must include en, the source language"
}

# print_inputs: the resolved inputs, and the arguments that reproduce them.
print_inputs() {
    cat <<OUT
name            $name
display-name    $display_name
bundle-id       $bundle_id
repo            $repo
codeowner       $codeowner
copyright       Copyright © $(date +%Y) $holder
team-id         ${team_id:-(empty: ad-hoc signing)}
locales         $locales
OUT
    printf 'args           '
    printf ' %q' --name "$name" --display-name "$display_name" --bundle-id "$bundle_id" \
        --repo "$repo" --codeowner "$codeowner" --copyright "$holder" --team-id "$team_id" \
        --locales "$locales"
    printf '\n'
}

# --- Edits --------------------------------------------------------------------------

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

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

# edit FILE sed-args...: put FILE through `sed -E sed-args`, without sed -i (BSD and
# GNU sed differ there).
edit() {
    local file=$1
    shift
    [[ -f $file ]] || die "no $file"
    sed -E "$@" "$file" >"$TMP/edited"
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
