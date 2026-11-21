#!/usr/bin/env bash
# Where the project stands on its route from template to release, and what comes next.
# Read-only; exits 0 whatever it finds. One line per step, in route order:
#   ok    done
#   todo  still to do; the first one is next
#   --    optional, not started
#   ?     could not tell; the line says why
# The last line is `next: <what to do next>`. The repo line needs gh signed in.
#
#   status.sh

source "$(dirname "$0")/common.sh"

# icon_digest of the template's App/Application/AppIcon.icon: the icon line says todo until
# the app has its own. The name the template ships with tells the template from an app
# made from it; init.sh deletes it, with the marked block it sits in.
TEMPLATE_ICON=4cdc776211ae4d78f4c25e8ae5086825364effbd8e668a8138c41b22d7e3c720
# template-only:start
TEMPLATE_NAME=Pomelo
# template-only:end

next=""
# line state step detail [what to do about it]
line() {
    say "$1" "$(printf '%-9s %s%s' "$2" "$3" "${4:+ → $4}")"
    if [[ $1 == todo && -z $next ]]; then
        next=$4
    fi
}

# make doctor checks the toolchain in detail; this line only says whether setup has run.
if ! xcodebuild -version >/dev/null 2>&1; then
    line todo setup "xcodebuild does not run; install Xcode $(tr -d '[:space:]' <.xcode-version)" "make setup"
elif ! grep -qs lefthook "$(git rev-parse --git-path hooks/pre-commit)"; then
    line todo setup "the git hooks are not installed" "make setup"
else
    line ok setup "git hooks installed; make doctor checks the toolchain"
fi

# template-only:start
if [[ $APP_NAME == "$TEMPLATE_NAME" ]]; then
    line todo project "still the template" "set the app's name and bundle id"
else
    # template-only:end
    line ok project "$APP_DISPLAY_NAME, $BUNDLE_ID"
# template-only:start
fi
# template-only:end

if ! command -v gh >/dev/null; then
    line "?" repo "gh is not installed: brew install gh"
elif ! gh auth status >/dev/null 2>&1; then
    line "?" repo "gh is not signed in: gh auth login"
elif ! repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>&1); then
    line "?" repo "no GitHub repository for this clone: $repo"
# gh api prints the response on stdout and its one-line error on stderr; only the error is read.
elif error=$(gh api "repos/$repo/branches/main/protection" 2>&1 >/dev/null); then
    line ok repo "$repo: main is protected"
elif [[ $error == *"Branch not protected"* ]]; then
    line todo repo "$repo: main is not protected" "make github-settings"
elif [[ $error == *"Branch not found"* ]]; then
    line todo repo "$repo: main is not pushed yet" "git push origin main, then make github-settings"
else
    line "?" repo "$repo: cannot read main's protection: ${error#gh: }"
fi

if [[ $(icon_digest) == "$TEMPLATE_ICON" ]]; then
    line todo icon "App/Application/AppIcon.icon is the template's" "design the app's icon"
else
    line ok icon "the app's own AppIcon.icon"
fi

# The release pipeline ships with the repository: these are its one-time settings. Read
# the secret names only, never their values.
if [[ -z $(plutil -extract SUPublicEDKey raw App/Configs/Info.plist 2>/dev/null) ]]; then
    line todo releases "no update-signing key yet" "make sparkle-key"
elif ! environment=$(gh api "repos/{owner}/{repo}/environments/release" 2>&1 >/dev/null); then
    if [[ $environment == *"Not Found"* ]]; then
        line todo releases "no release environment on ${repo:-this repository} yet" "make github-settings"
    else
        line "?" releases "cannot read the release environment: ${environment#gh: }"
    fi
elif ! secrets=$(gh secret list --env release --json name --jq '.[].name' 2>&1); then
    line "?" releases "cannot list the release environment's secrets: ${secrets#gh: }"
else
    secret_list=(SPARKLE_ED_PRIVATE_KEY)
    if [[ -n ${TEAM_ID:-} ]]; then
        secret_list+=(DEVELOPER_ID_P12_BASE64 DEVELOPER_ID_P12_PASSWORD NOTARY_API_KEY_P8_BASE64 NOTARY_API_KEY_ID NOTARY_API_ISSUER_ID)
    fi
    missing=""
    for secret in "${secret_list[@]}"; do
        if ! grep -qxF "$secret" <<<"$secrets"; then
            missing=$secret
            break
        fi
    done
    if [[ -n $missing ]]; then
        line todo releases "secret $missing is not in the release environment" "docs/RELEASING.md, before the first release"
    else
        line ok releases "ready: Actions → Release → Run workflow"
    fi
fi

if [[ -n ${TEAM_ID:-} ]]; then
    line ok signing "Developer ID, team $TEAM_ID"
else
    line -- signing "ad-hoc (optional)" "get a Developer ID"
fi

echo "next: ${next:-nothing required}"
