#!/usr/bin/env bash
# Homebrew cask for the current release DMG.
#   print  writes the cask to stdout
#   push   commits Casks/<token>.rb to the tap repo $HOMEBREW_TAP (owner/homebrew-tap)
#          through the GitHub API; GH_TOKEN needs contents:write on the tap
# Homebrew quarantines downloads, so an ad-hoc build installs but Gatekeeper blocks it.

source "$(dirname "$0")/common.sh"

dmg="dist/$APP_NAME-$VERSION.dmg"
token=$(tr '[:upper:]' '[:lower:]' <<<"$APP_NAME")

cask() {
    [[ -f $dmg ]] || die "no DMG at $dmg; run make release first"
    local sha min_macos macos
    sha=$(shasum -a 256 "$dmg" | awk '{ print $1 }')
    min_macos=$(swift package dump-package | jq -r '.platforms[] | select(.platformName == "macos") | .version')
    case ${min_macos%%.*} in
        14) macos=sonoma ;;
        15) macos=sequoia ;;
        26) macos=tahoe ;;
        *) die "no Homebrew macOS symbol for $min_macos" ;;
    esac
    cat <<EOF
cask "$token" do
  version "$VERSION"
  sha256 "$sha"

  url "$RELEASES_URL/download/v#{version}/$APP_NAME-#{version}.dmg"
  name "$APP_DISPLAY_NAME"
  homepage "${RELEASES_URL%/releases}"

  auto_updates true
  depends_on macos: ">= :$macos"

  app "$APP_NAME.app"

  zap trash: "~/Library/Containers/$BUNDLE_ID"
end
EOF
}

case ${1:-} in
    print) cask ;;
    push)
        [[ -n ${HOMEBREW_TAP:-} ]] || die "set HOMEBREW_TAP=owner/homebrew-tap"
        path="Casks/$token.rb"
        content=$(cask | base64)
        args=(-X PUT "repos/$HOMEBREW_TAP/contents/$path" -f message="chore($token): update to $VERSION" -f content="$content")
        # A first release has no file yet: the lookup 404s and the PUT creates it.
        if existing=$(gh api "repos/$HOMEBREW_TAP/contents/$path" --jq .sha 2>/dev/null); then
            args+=(-f sha="$existing")
        fi
        gh api "${args[@]}" >/dev/null
        log "updated $HOMEBREW_TAP/$path to $VERSION"
        ;;
    *) die "usage: update-cask.sh print|push" ;;
esac
