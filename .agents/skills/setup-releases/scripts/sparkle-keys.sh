#!/usr/bin/env bash
# Writes this app's Sparkle EdDSA public key into App/Configs/Info.plist and prints how
# to hand the private key to CI.
#
#   sparkle-keys.sh create          creates the key in the login keychain, or reuses it
#   sparkle-keys.sh restore FILE    imports a backed-up key file (a new Mac, or a key
#                                   exported with generate_keys -x)
#
# The keychain account is the app's bundle identifier, so one Mac can hold the keys of
# several apps.

# shellcheck source=../../../../scripts/common.sh
source "$(dirname "$0")/../../../../scripts/common.sh"

usage() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0" >&2
    exit "$1"
}

[[ $# -ge 1 ]] || usage 1
swift package resolve >&2
sparkle_bin=$SPARKLE_BIN
[[ -x $sparkle_bin/generate_keys ]] || die "Sparkle tools missing at $sparkle_bin"

case $1 in
    create)
        "$sparkle_bin/generate_keys" --account "$BUNDLE_ID" >&2
        ;;
    restore)
        [[ $# -eq 2 && -f ${2:-} ]] || die "usage: sparkle-keys.sh restore FILE"
        "$sparkle_bin/generate_keys" --account "$BUNDLE_ID" -f "$2" >&2
        ;;
    *) usage 1 ;;
esac

public_key=$("$sparkle_bin/generate_keys" --account "$BUNDLE_ID" -p)
[[ -n $public_key ]] || die "generate_keys printed no public key"

set_sparkle_public_key "$public_key"
log "SUPublicEDKey written to App/Configs/Info.plist; commit it"

cat >&2 <<EOF

Next, once per app:
  1. Export and back up the private key offline. Losing it means installed
     copies can never update again.
       $sparkle_bin/generate_keys --account $BUNDLE_ID -x sparkle-private-key
  2. Give it to CI, then delete the exported file:
       gh secret set SPARKLE_ED_PRIVATE_KEY --env release < sparkle-private-key
       rm sparkle-private-key
  3. On a new Mac, import the backup instead of generating a second key:
       $(basename "$0") restore <file>
EOF
