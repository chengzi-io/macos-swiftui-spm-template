#!/usr/bin/env bash
# Creates this app's Sparkle EdDSA key in the login keychain (or reuses it), writes
# the public key into App/Configs/Info.plist and prints how to hand the private key to CI.

# shellcheck source=../../../../scripts/common.sh
source "$(dirname "$0")/../../../../scripts/common.sh"

swift package resolve >&2
sparkle_bin=$SPARKLE_BIN
[[ -x $sparkle_bin/generate_keys ]] || die "Sparkle tools missing at $sparkle_bin"

"$sparkle_bin/generate_keys" --account "$BUNDLE_ID" >&2
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
EOF
