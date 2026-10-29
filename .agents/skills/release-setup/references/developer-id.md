# Developer ID signing

Step 4 of the release setup, for releases signed with a Developer ID and notarized.
Without one, releases are ad-hoc signed: no hardened runtime (its library validation
would reject the embedded Sparkle framework) and no notarization.

## What users get

| What users get | Ad-hoc (default) | Developer ID |
| --- | --- | --- |
| First launch | Blocked by Gatekeeper, once: System Settings → Privacy & Security → **Open Anyway** | Opens |
| Updates through Sparkle | Work: EdDSA proves they came from you, and no Gatekeeper prompt | Work |
| Permissions (camera, screen recording, accessibility…) and keychain items | May be asked for again after an update: every build has a new signature | Kept |
| Homebrew cask (`homebrew-cask` skill) | Own tap only: blocked at first launch, or the cask clears the quarantine flag; README.md says which | Installs, and can go to the official `homebrew/cask` |

## Set it up

The user does steps 1, 2 and 4; they hold the Apple account and type the secrets.

1. Join the Apple Developer Program. Create a **Developer ID Application** certificate
   (Xcode → Settings → Accounts → Manage Certificates, as Account Holder) and export it
   with its private key from Keychain Access as a `.p12`.
2. App Store Connect → Users and Access → Integrations → App Store Connect API: create a
   team key with the Developer role; download the `.p8` once; note the key ID and the
   issuer ID.
3. Set `TEAM_ID` in `App/Configs/Identity.xcconfig`; commit it on a branch and open a PR.
4. Store the secrets in the `release` environment, then delete the exported files:

   ```bash
   base64 -i developer-id.p12 | gh secret set DEVELOPER_ID_P12_BASE64 --env release
   gh secret set DEVELOPER_ID_P12_PASSWORD --env release
   base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set NOTARY_API_KEY_P8_BASE64 --env release
   gh secret set NOTARY_API_KEY_ID --env release --body XXXXXXXXXX
   gh secret set NOTARY_API_ISSUER_ID --env release --body <issuer uuid>
   ```

   The publish job imports them into a temporary keychain and deletes it when the job
   ends.
5. For local releases, keep the certificate in the login keychain and store notary
   credentials once:

   ```bash
   xcrun notarytool store-credentials notary --key AuthKey_XXXXXXXXXX.p8 \
     --key-id XXXXXXXXXX --issuer <issuer uuid>
   NOTARY_PROFILE=notary make release
   ```

With `TEAM_ID` set, a missing certificate or notary secret fails the release instead of
falling back to ad-hoc. `make doctor` checks for the certificate on this Mac.

## Check a notarized build

```bash
spctl --assess --type execute -vv dist/<App>.app          # source=Notarized Developer ID
spctl -a -t open --context context:primary-signature -vv dist/<App>-X.Y.Z.dmg
xcrun stapler validate dist/<App>-X.Y.Z.dmg
```

## Moving from ad-hoc

Keep the same Sparkle key: existing installs accept the first Developer ID update by
its EdDSA signature. This transition has not been exercised yet; try it with a test
build before relying on it.
