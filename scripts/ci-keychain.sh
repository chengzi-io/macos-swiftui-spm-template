#!/usr/bin/env bash
# CI only.
#   setup    checks that SPARKLE_ED_PRIVATE_KEY is set, imports the Developer ID
#            certificate into a temporary keychain and writes the notary API key to
#            $RUNNER_TEMP, exporting NOTARY_KEY_PATH
#   cleanup  deletes both
# With TEAM_ID empty the release is ad-hoc signed and there is nothing to import.

source "$(dirname "$0")/common.sh"

[[ -n ${RUNNER_TEMP:-} ]] || die "ci-keychain.sh runs in GitHub Actions only"
keychain="$RUNNER_TEMP/signing.keychain-db"
key_path="$RUNNER_TEMP/notary-key.p8"

case ${1:-} in
    setup)
        # appcast.sh signs with it only after the build and notarization.
        [[ -n ${SPARKLE_ED_PRIVATE_KEY:-} ]] ||
            die "secret SPARKLE_ED_PRIVATE_KEY is empty; see docs/RELEASING.md, One-time setup, step 3"
        if [[ -z ${TEAM_ID:-} ]]; then
            log "TEAM_ID empty: ad-hoc release, no signing credentials to import"
            exit 0
        fi
        for secret in DEVELOPER_ID_P12_BASE64 DEVELOPER_ID_P12_PASSWORD NOTARY_API_KEY_P8_BASE64; do
            [[ -n ${!secret:-} ]] || die "TEAM_ID is set but secret $secret is empty"
        done

        password=$(openssl rand -base64 24)
        certificate="$RUNNER_TEMP/developer-id.p12"
        printf '%s' "$DEVELOPER_ID_P12_BASE64" | base64 --decode >"$certificate"
        security create-keychain -p "$password" "$keychain"
        security set-keychain-settings -lut 21600 "$keychain"
        security unlock-keychain -p "$password" "$keychain"
        security import "$certificate" -k "$keychain" -P "$DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign
        security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain" >/dev/null
        # shellcheck disable=SC2046 # word-split the existing search list on purpose
        security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')
        rm -f "$certificate"
        signing_identity >/dev/null

        printf '%s' "$NOTARY_API_KEY_P8_BASE64" | base64 --decode >"$key_path"
        echo "NOTARY_KEY_PATH=$key_path" >>"$GITHUB_ENV"
        log "signing credentials imported"
        ;;
    cleanup)
        if [[ -f $keychain ]]; then
            security delete-keychain "$keychain"
        fi
        rm -f "$key_path"
        ;;
    *) die "usage: ci-keychain.sh setup|cleanup" ;;
esac
