#!/usr/bin/env bash
# Creates this app's Sparkle EdDSA key in the login keychain (or reuses it), writes
# the public key into Bundle/app.env and prints how to hand the private key to CI.

source "$(dirname "$0")/common.sh"

swift package resolve >&2
sparkle_bin=.build/artifacts/sparkle/Sparkle/bin
[[ -x $sparkle_bin/generate_keys ]] || die "Sparkle tools missing at $sparkle_bin"

"$sparkle_bin/generate_keys" --account "$BUNDLE_ID" >&2
public_key=$("$sparkle_bin/generate_keys" --account "$BUNDLE_ID" -p)
[[ -n $public_key ]] || die "generate_keys printed no public key"

sed -i '' "s|^SPARKLE_PUBLIC_KEY=.*|SPARKLE_PUBLIC_KEY=$public_key|" Bundle/app.env
log "SPARKLE_PUBLIC_KEY written to Bundle/app.env; commit it"

cat >&2 <<EOF

Next, once per app:
  1. Export and back up the private key offline. Losing it means installed
     copies can never update again.
       $sparkle_bin/generate_keys --account $BUNDLE_ID -x sparkle-private-key
  2. Give it to CI, then delete the exported file:
       gh secret set SPARKLE_ED_PRIVATE_KEY --env release < sparkle-private-key
       rm sparkle-private-key
EOF
