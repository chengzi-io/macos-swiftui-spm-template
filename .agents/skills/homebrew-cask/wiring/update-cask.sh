#!/usr/bin/env bash
# Homebrew cask for the current release DMG, dist/$APP_NAME-$VERSION.dmg.
#   print  writes the cask to stdout
#   push   commits Casks/<token>.rb to the tap $HOMEBREW_TAP (App/Configs/Identity.xcconfig)
#          through the GitHub API; GH_TOKEN needs contents:write on the tap
# Homebrew quarantines what it downloads, so Gatekeeper checks the app on first launch.
# A Developer ID build passes and gets a plain cask. An ad-hoc build (TEAM_ID empty)
# gets what HOMEBREW_UNSIGNED in App/Configs/Identity.xcconfig picks:
#   caveats  the cask tells the user to click Open Anyway after macOS blocks the launch
#   xattr    the cask clears the quarantine flag after installing, so macOS never checks
#            the app; homebrew/cask never accepts such a cask

source "$(dirname "$0")/common.sh"

dmg="dist/$APP_NAME-$VERSION.dmg"
token=$(tr '[:upper:]' '[:lower:]' <<<"$APP_NAME")

cask() {
    [[ -f $dmg ]] || die "no DMG at $dmg; run make release first"
    local sha min_macos macos unsigned=""
    sha=$(shasum -a 256 "$dmg" | awk '{ print $1 }')
    min_macos=$(sed -nE 's/^MACOSX_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*//p' App/Configs/Project.xcconfig)
    case ${min_macos%%.*} in
        14) macos=sonoma ;;
        15) macos=sequoia ;;
        26) macos=tahoe ;;
        *) die "no Homebrew macOS symbol for $min_macos; add it to scripts/update-cask.sh" ;;
    esac
    if [[ -z ${TEAM_ID:-} ]]; then
        unsigned=${HOMEBREW_UNSIGNED:-}
        [[ $unsigned == caveats || $unsigned == xattr ]] ||
            die "TEAM_ID is empty: set HOMEBREW_UNSIGNED in App/Configs/Identity.xcconfig to caveats or xattr"
    elif [[ -n ${HOMEBREW_UNSIGNED:-} ]]; then
        log "TEAM_ID is set, so the cask ignores HOMEBREW_UNSIGNED; remove it and its README notice"
    fi

    cat <<EOF
cask "$token" do
  version "$VERSION"
  sha256 "$sha"

  url "$RELEASES_URL/download/v#{version}/$APP_NAME-#{version}.dmg"
  name "$APP_DISPLAY_NAME"
  homepage "${RELEASES_URL%/releases}"

  auto_updates true
  depends_on macos: :$macos

  app "$APP_NAME.app"

EOF
    if [[ $unsigned == xattr ]]; then
        cat <<EOF
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/$APP_NAME.app"]
  end

EOF
    fi
    # A sandboxed app leaves both directories behind.
    cat <<EOF
  zap trash: [
    "~/Library/Application Scripts/$BUNDLE_ID",
    "~/Library/Containers/$BUNDLE_ID",
  ]
EOF
    if [[ $unsigned == caveats ]]; then
        cat <<EOF

  caveats <<~CAVEATS
    $APP_DISPLAY_NAME is not signed with an Apple Developer ID, so macOS blocks its first
    launch. Open System Settings → Privacy & Security and click Open Anyway, once.
  CAVEATS
EOF
    fi
    echo "end"
}

case ${1:-} in
    print) cask ;;
    push)
        [[ -n ${HOMEBREW_TAP:-} ]] || die "set HOMEBREW_TAP in App/Configs/Identity.xcconfig to owner/homebrew-tap"
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
