#!/usr/bin/env bash
# Where the project stands on its route from template to release, and what comes next.
# Read-only; exits 0 whatever it finds. One line per step, in route order:
#   ok    done
#   todo  still to do; the first one is next
#   --    optional, not started
#   ?     could not tell; the line says why
# The last line is `next: <skill or command>`. The repo line needs gh signed in.
#
#   status.sh

source "$(dirname "$0")/common.sh"

# icon_digest of the template's App/Application/AppIcon.icon. lint-rules.sh fails while the
# template's init skill is here and this no longer matches the icon.
TEMPLATE_ICON=4cdc776211ae4d78f4c25e8ae5086825364effbd8e668a8138c41b22d7e3c720

next=""
# line state step detail [what to run]
line() {
    printf '  %-5s %-9s %s%s\n' "$1" "$2" "$3" "${4:+ → $4}"
    if [[ $1 == todo && -z $next ]]; then
        next=$4
    fi
}

pinned=$(tr -d '[:space:]' <.xcode-version)
hooks=$(git rev-parse --git-path hooks/pre-commit)
if ! xcode=$(xcodebuild -version 2>/dev/null | awk 'NR == 1 { print $2 }') || [[ -z $xcode ]]; then
    line todo setup "xcodebuild does not run; install Xcode $pinned" "make setup"
elif ! grep -qs lefthook "$hooks"; then
    line todo setup "the git hooks are not installed" "make setup"
elif [[ $xcode != "$pinned" ]]; then
    line ok setup "Xcode $xcode, while .xcode-version and CI use $pinned (make doctor)"
else
    line ok setup "Xcode $xcode, git hooks installed"
fi

# template-only:start
if [[ -d .agents/skills/setup-project ]]; then
    line todo project "still the template" setup-project
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
    line todo repo "$repo: main is not protected" "release-setup, step 1"
elif [[ $error == *"Branch not found"* ]]; then
    line todo repo "$repo: main is not pushed yet" "git push origin main, then release-setup, step 1"
else
    line "?" repo "$repo: cannot read main's protection: ${error#gh: }"
fi

if [[ $(icon_digest) == "$TEMPLATE_ICON" ]]; then
    line todo icon "App/Application/AppIcon.icon is the template's" app-icon
else
    line ok icon "the app's own AppIcon.icon"
fi

if [[ -d Sources/Features/Notes ]]; then
    line todo demo "Notes, the template's demo, is still there" "add-feature: build the first feature"
else
    line ok demo "the Notes demo is gone"
fi

if [[ -d App/Configs/DMG ]]; then
    line ok dmg "a designed window (App/Configs/DMG)"
else
    line -- dmg "the plain window (optional)" dmg
fi

if ! sparkle_key=$(plutil -extract SUPublicEDKey raw App/Configs/Info.plist 2>/dev/null); then
    line "?" releases "App/Configs/Info.plist has no SUPublicEDKey"
elif [[ -z $sparkle_key ]]; then
    line -- releases "not set up (optional until you ship)" release-setup
else
    line "?" releases "the Sparkle key is set; release-setup's scripts/check.sh checks the rest"
fi

if [[ -n ${TEAM_ID:-} ]]; then
    line ok signing "Developer ID, team $TEAM_ID"
else
    line -- signing "ad-hoc (optional)" "release-setup, Developer ID"
fi

if [[ -f scripts/update-cask.sh ]]; then
    line ok homebrew "every release updates the own tap"
else
    line -- homebrew "not set up (optional, after the first release)" homebrew-cask
fi

echo "next: ${next:-nothing required; build the app with add-feature}"
