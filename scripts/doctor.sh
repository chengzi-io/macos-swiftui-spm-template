#!/usr/bin/env bash
# Checks the local toolchain. Exits non-zero with a fix hint on the first hard gap.

source "$(dirname "$0")/common.sh"

xcode_major=26

ok() { echo "ok    $*"; }
warn() { echo "warn  $*"; }

developer_dir=$(xcode-select -p)
[[ $developer_dir == *.app/Contents/Developer ]] ||
    die "xcode-select points to $developer_dir; run: sudo xcode-select -s /Applications/Xcode.app"
ok "xcode-select: $developer_dir"

xcode_version=$(xcodebuild -version | awk 'NR == 1 { print $2 }')
[[ ${xcode_version%%.*} == "$xcode_major" ]] || die "Xcode $xcode_version found; this repo needs Xcode $xcode_major.x"
ok "Xcode $xcode_version"

# Coding agents build, test and render previews through Xcode with it (Xcode 26.3+).
if xcrun --find mcpbridge >/dev/null 2>&1; then
    ok "xcrun mcpbridge (Xcode MCP server for agents)"
else
    warn "no xcrun mcpbridge: agents need Xcode 26.3 or later to work through Xcode"
fi

swift format --version >/dev/null || die "swift format missing from the toolchain"
ok "swift format $(swift format --version)"

command -v jq >/dev/null || die "jq missing (ships with macOS 15+); run: brew install jq"
ok "jq"

command -v lefthook >/dev/null || die "lefthook missing; run: brew install lefthook"
ok "lefthook $(lefthook version)"

# Release prerequisites are only needed for local releases; CI imports its own.
if [[ -z ${TEAM_ID:-} ]]; then
    warn "TEAM_ID empty: release builds are ad-hoc signed and not notarized"
elif [[ -n $(find_identity "Developer ID Application") ]]; then
    ok "Developer ID Application identity for $TEAM_ID"
else
    warn "no Developer ID Application identity for $TEAM_ID in the keychain (needed for local releases)"
fi
