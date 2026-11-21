#!/usr/bin/env bash
# Checks the toolchain. Exits non-zero with a fix hint on the first hard gap.
# .xcode-version is the Xcode CI runs; a different local Xcode is a warning, in CI an error.

source "$(dirname "$0")/../common.sh"

say info "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"

pinned_xcode=$(tr -d '[:space:]' <.xcode-version)
[[ $pinned_xcode =~ ^[0-9]+(\.[0-9]+)+$ ]] || die ".xcode-version must hold a version such as 26.2, found: $pinned_xcode"

developer_dir=$(xcode-select -p)
[[ $developer_dir == *.app/Contents/Developer ]] ||
    die "xcode-select points to $developer_dir; run: sudo xcode-select -s /Applications/Xcode.app"
say ok "xcode-select: $developer_dir"

xcode_version=$(xcodebuild -version | awk 'NR == 1 { print $2 }')
if [[ $xcode_version == "$pinned_xcode" ]]; then
    say ok "Xcode $xcode_version (.xcode-version)"
elif [[ -n ${CI:-} ]]; then
    die "Xcode $xcode_version selected; .xcode-version pins $pinned_xcode"
elif ((${xcode_version%%.*} < ${pinned_xcode%%.*})); then
    die "Xcode $xcode_version found; this repo needs Xcode $pinned_xcode (.xcode-version)"
else
    say warn "Xcode $xcode_version: CI builds with Xcode $pinned_xcode (.xcode-version); results can differ"
fi

xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1 ||
    die "Xcode's first launch tasks have not run; run: sudo xcodebuild -runFirstLaunch"
say ok "Xcode first launch done"

# Coding agents can build, test and render previews through Xcode with it: Xcode 26.3+
# on macOS 26+. Optional: everything else goes through make and xcodebuild.
macos_major=$(sw_vers -productVersion | cut -d. -f1)
if xcrun --find mcpbridge >/dev/null 2>&1 && ((macos_major >= 26)); then
    say ok "xcrun mcpbridge (Xcode MCP server for agents)"
else
    say info "no xcrun mcpbridge (optional, needs Xcode 26.3+ on macOS 26+): agents work through make and xcodebuild"
fi

swift format --version >/dev/null || die "swift format missing from the toolchain"
say ok "swift format $(swift format --version)"

command -v jq >/dev/null || die "jq missing (ships with macOS 15+); run: brew install jq"
say ok "jq"

# The rest is for this Mac only: git hooks, gh for pull requests and publishing, and local
# releases. CI needs none of it.
if [[ -n ${CI:-} ]]; then
    exit 0
fi

command -v lefthook >/dev/null || die "lefthook missing; run: brew install lefthook"
say ok "lefthook $(lefthook version)"

if ! command -v gh >/dev/null; then
    say warn "gh missing (pull requests, release setup); run: brew install gh"
elif ! gh auth status >/dev/null 2>&1; then
    say warn "gh not logged in (pull requests, release setup); run: gh auth login"
else
    say ok "gh logged in"
fi

if [[ -z ${TEAM_ID:-} ]]; then
    say info "TEAM_ID empty: release builds are ad-hoc signed and not notarized"
elif [[ -n $(find_identity "Developer ID Application") ]]; then
    say ok "Developer ID Application identity for $TEAM_ID"
else
    say warn "no Developer ID Application identity for $TEAM_ID in the keychain (needed for local releases)"
fi
