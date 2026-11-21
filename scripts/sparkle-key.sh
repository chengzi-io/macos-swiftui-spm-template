#!/usr/bin/env bash
# Writes this app's Sparkle EdDSA public key into App/Configs/Info.plist and prints how
# to hand the private key to CI. docs/RELEASING.md covers the setup around it.
#
#   sparkle-key.sh create          creates the key in the login keychain, or reuses it
#   sparkle-key.sh restore FILE    imports a backed-up key file (a new Mac, or a key
#                                  exported with generate_keys -x)
#
# The keychain account is the app's bundle identifier, so one Mac can hold the keys of
# several apps.

source "$(dirname "$0")/common.sh"

usage() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0" >&2
    exit "$1"
}

[[ $# -ge 1 ]] || usage 1
swift package resolve >&2
sparkle_bin=.build/artifacts/sparkle/Sparkle/bin
[[ -x $sparkle_bin/generate_keys ]] || die "Sparkle tools missing at $sparkle_bin"

case $1 in
    create)
        # An app that has shipped already carries its key in Info.plist, and installed copies
        # trust only that key: a second key would make every one of them reject every
        # update. -p looks the key up and prints it; it creates nothing in the keychain.
        current=$(plutil -extract SUPublicEDKey raw App/Configs/Info.plist 2>/dev/null || true)
        if [[ -n $current ]]; then
            held=$("$sparkle_bin/generate_keys" --account "$BUNDLE_ID" -p 2>/dev/null || true)
            [[ $held == "$current" ]] ||
                die "App/Configs/Info.plist already has an update-signing key, and this Mac does not hold its private key; restore your backup: make sparkle-key RESTORE=<file>"
        fi
        "$sparkle_bin/generate_keys" --account "$BUNDLE_ID" >&2
        ;;
    restore)
        [[ $# -eq 2 && -f ${2:-} ]] || die "usage: sparkle-key.sh restore FILE"
        "$sparkle_bin/generate_keys" --account "$BUNDLE_ID" -f "$2" >&2
        ;;
    *) usage 1 ;;
esac

public_key=$("$sparkle_bin/generate_keys" --account "$BUNDLE_ID" -p)
[[ -n $public_key ]] || die "generate_keys printed no public key"

# In place, keeping the file's formatting (plutil and PlistBuddy rewrite it with tabs).
sed -i '' -e '/<key>SUPublicEDKey<\/key>/{' -e 'n' -e "s|<string>.*</string>|<string>$public_key</string>|" -e '}' App/Configs/Info.plist
[[ $(plutil -extract SUPublicEDKey raw App/Configs/Info.plist) == "$public_key" ]] ||
    die "could not set SUPublicEDKey in App/Configs/Info.plist"
log "SUPublicEDKey written to App/Configs/Info.plist; commit it"

cat >&2 <<EOF

Next, once per app:
  1. Export the private key to a file:
       $sparkle_bin/generate_keys --account $BUNDLE_ID -x sparkle-private-key
  2. Back that file up offline now, in a password manager or on a USB drive. The copy
     stored in GitHub is no backup: a secret cannot be read back out of it. Losing the
     key means installed copies can never update again.
  3. Store it as the release environment's secret:
       gh secret set SPARKLE_ED_PRIVATE_KEY --env release < sparkle-private-key
  4. Delete the file:
       rm sparkle-private-key
  5. On a new Mac, restore the backup; never generate a second key:
       make sparkle-key RESTORE=<file>

Where the key goes and what the first release needs: docs/RELEASING.md.
EOF
