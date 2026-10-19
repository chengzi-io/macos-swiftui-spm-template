# Releasing

## How a release happens

1. PRs are squash-merged into `main`; each PR title is a Conventional Commit.
2. On every push to `main`, release-please updates a release PR: the next version in
   `version.txt` and `.release-please-manifest.json`, and the new `CHANGELOG.md`
   section. `feat` bumps the minor version and `fix` the patch while the version is
   below 1.0 (`bump-minor-pre-major`); `chore`, `docs`, `ci` and the like release
   nothing.
3. The release PR must pass `Release dry run` (`make release-dry-run`): the universal
   release build, ad-hoc signed, smoke-tested, packaged and checked as a DMG.
4. Merging the release PR makes release-please tag `vX.Y.Z` and create the GitHub
   Release with the changelog, as a **draft**: nobody sees it yet, and
   `releases/latest` still points at the previous version.
5. The `Publish macOS app` job checks out the tag and runs `make lint test` and
   `make release`, which:
   - builds `dist/<App>.app` (universal), signs it, smoke-tests it, notarizes it
     (Developer ID only);
   - packages, signs and notarizes `dist/<App>-X.Y.Z.dmg`, mounts it and smoke-tests
     the app inside, with a Gatekeeper check when there is a Developer ID;
   - zips the dSYM, writes `appcast.xml` (EdDSA-signed) and checks its URL, length and
     signature against `SPARKLE_PUBLIC_KEY`, then writes `SHA256SUMS`.

   It then uploads those files to the draft and publishes it, keeps the dSYM as a
   workflow artifact for 90 days, and updates the Homebrew cask when a tap is
   configured.
6. Installed apps read `releases/latest/download/appcast.xml`, find the new version
   and update through Sparkle.

`CFBundleShortVersionString` comes from `version.txt`; `CFBundleVersion` is
`git rev-list --count HEAD`, which only grows on `main` and is what Sparkle compares.

## One-time setup

Run these once per repository, after the first push of `main`.

### 1. Repository settings

```bash
make github-setup
```

Squash merge only, with the PR title as the commit title; `main` requires a PR plus
the `Validate PR title`, `Lint, test, build` and `Release dry run` checks; the
workflow token is read-only; the `release` environment only runs from protected
branches; private vulnerability reporting is on. The script prints the settings it
reads back.

`Release dry run` runs only on release-please's own PRs (branch `release-please--*` in
this repository), and the other two checks skip them; a skipped required check counts
as passed. The dry run is `make release-dry-run`: the universal release build, its
smoke test, the DMG and the checks on it, ad-hoc signed because PRs get no signing
secrets. Merging the release PR tags the release, so a release build that breaks shows
up here instead of after the tag.

### 2. GitHub App for release-please

A PR opened with the default `GITHUB_TOKEN` starts no workflows, so its required
checks never report and it can never merge. release-please therefore runs on a
GitHub App token.

1. GitHub → Settings → Developer settings → GitHub Apps → New GitHub App. Webhook off.
   Repository permissions: Contents read and write, Pull requests read and write.
2. Generate a private key, then install the App on this repository.
3. Store its client ID and key:

   ```bash
   gh variable set RELEASE_APP_CLIENT_ID --body "<client id>"
   gh secret set RELEASE_APP_PRIVATE_KEY < release-app.private-key.pem
   ```

One App can serve every repository created from this template.

### 3. Sparkle signing key

```bash
make sparkle-keys
```

Creates an EdDSA key in your login keychain (account = bundle identifier), writes the
public key to `Bundle/app.env` (commit it) and prints the two commands that export the
private key and store it as the `SPARKLE_ED_PRIVATE_KEY` secret of the `release`
environment. Back the private key up offline: without it, installed copies can never
update again. Release builds fail while `SPARKLE_PUBLIC_KEY` is empty.

### 4a. Without a Developer ID (default)

Leave `TEAM_ID` empty in `Bundle/app.env`. Releases are ad-hoc signed, without the
hardened runtime (its library validation would reject the embedded Sparkle framework)
and without notarization. The publish job adds a note to the release explaining the
first launch. What users see:

- First launch is blocked by Gatekeeper. They open System Settings → Privacy &
  Security and click **Open Anyway**, once.
- Updates through Sparkle work: EdDSA proves the update came from you, and Sparkle
  installs it without the Gatekeeper prompt. Verified locally with two ad-hoc,
  sandboxed builds (0.1.0 → 0.1.1).
- Every build has a new ad-hoc signature, so permissions granted in System Settings
  (camera, screen recording, accessibility…) and keychain items may be asked for
  again after an update.
- Homebrew quarantines cask downloads, so a cask install is blocked the same way.

### 4b. With a Developer ID

1. Join the Apple Developer Program. Create a **Developer ID Application** certificate
   (Xcode → Settings → Accounts → Manage Certificates, as Account Holder) and export it
   with its private key from Keychain Access as a `.p12`.
2. App Store Connect → Users and Access → Integrations → App Store Connect API: create a
   team key with the Developer role; download the `.p8` once; note the key ID and the
   issuer ID.
3. Set `TEAM_ID` in `Bundle/app.env` and commit.
4. Store the secrets in the `release` environment:

   ```bash
   base64 -i developer-id.p12 | gh secret set DEVELOPER_ID_P12_BASE64 --env release
   gh secret set DEVELOPER_ID_P12_PASSWORD --env release
   base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set NOTARY_API_KEY_P8_BASE64 --env release
   gh secret set NOTARY_API_KEY_ID --env release --body XXXXXXXXXX
   gh secret set NOTARY_API_ISSUER_ID --env release --body <issuer uuid>
   ```

   Then delete the exported files. The publish job imports them into a temporary
   keychain and deletes it when the job ends.
5. For local releases, keep the certificate in your login keychain and store notary
   credentials once:

   ```bash
   xcrun notarytool store-credentials notary --key AuthKey_XXXXXXXXXX.p8 \
     --key-id XXXXXXXXXX --issuer <issuer uuid>
   NOTARY_PROFILE=notary make release
   ```

With `TEAM_ID` set, a missing certificate or notary secret fails the release instead
of falling back to ad-hoc.

Check a notarized build:

```bash
spctl --assess --type execute -vv dist/<App>.app          # source=Notarized Developer ID
spctl -a -t open --context context:primary-signature -vv dist/<App>-X.Y.Z.dmg
xcrun stapler validate dist/<App>-X.Y.Z.dmg
```

Moving from ad-hoc to Developer ID keeps the same Sparkle key, so existing installs
accept the first Developer ID update by its EdDSA signature. This transition has not
been exercised yet; try it with a test build before relying on it.

## Recovering from a failed or bad release

A failed publish job leaves the release a draft: users see nothing, and Sparkle keeps
offering the previous version. Read the job log, then:

- The failure is outside the repository (a runner or network hiccup, Apple's notary
  service, an expired certificate, a wrong secret): fix it and **Re-run failed jobs**.
  The job rebuilds the same tag.
- The tagged code is wrong: the tag cannot move, so delete the draft, merge a `fix:`
  PR and release the next version. The skipped version keeps its tag and its
  `CHANGELOG.md` section.

A release that went out broken: fix forward, merge a `fix:` PR and release again. To stop a broken update from
spreading meanwhile, mark the previous release as **Latest** on GitHub (edit release →
Set as the latest release): `releases/latest/download/appcast.xml` then serves the
previous appcast and Sparkle offers nothing newer. Never move or delete a published
tag.

## Symbolicating crashes

Each release carries `<App>-X.Y.Z.dSYM.zip` (also kept as a workflow artifact for 90
days). Open source projects can leave it on the release; for closed source, remove the
asset upload in `scripts/publish-github.sh` and rely on the private workflow artifact.

```bash
atos -o App.dSYM/Contents/Resources/DWARF/App -arch arm64 -l <load address> <address>
```

The dSYM matches by UUID, so the executable being renamed to `<App>` does not matter.

## Homebrew cask (optional)

1. Create `<owner>/homebrew-tap` with a `Casks/` directory.
2. Create a fine-grained token with Contents read and write on that repository only.
3. `gh variable set HOMEBREW_TAP --body <owner>/homebrew-tap` and
   `gh secret set HOMEBREW_TAP_TOKEN --env release`.

The publish job then writes `Casks/<app>.rb` (version, sha256, `auto_updates true`,
minimum macOS, zap path) after every release. Preview it with
`scripts/update-cask.sh print` after `make release`. Users install with
`brew install --cask <owner>/tap/<app>`. Useful only with a Developer ID (see 4a).

## Mac App Store (optional)

A separate path that leaves the Developer ID release untouched. `APP_STORE=1` removes
Sparkle at compile time (`Package.swift`, `#if !APP_STORE`); the App Store updates the
app.

1. Certificates: **Apple Distribution** and **Mac Installer Distribution** in your
   login keychain. `TEAM_ID` set.
2. App ID for the bundle identifier and a **Mac App Store** provisioning profile;
   download it.
3. Create the app record in App Store Connect.
4. Build and upload:

   ```bash
   MAS_PROVISIONING_PROFILE=~/Downloads/MyApp.provisionprofile make release-mas
   MAS_PROVISIONING_PROFILE=… NOTARY_KEY_PATH=AuthKey_X.p8 NOTARY_KEY_ID=X \
     NOTARY_ISSUER_ID=<uuid> make upload-mas
   ```

   The build embeds the profile, adds the application and team identifier
   entitlements, signs with Apple Distribution and wraps the app in
   `dist/mas/<App>-X.Y.Z.pkg` signed with the installer certificate.
5. Keep `Bundle/PrivacyInfo.xcprivacy` accurate (see [RECIPES.md](RECIPES.md)), then
   submit for review in App Store Connect.

This path has been checked up to signing with stand-in identities only; the first
real submission is its acceptance test.

## Beta channel (optional)

Not wired by default. When testers need builds ahead of `main` releases:

1. Release prereleases from a branch with its own release-please config
   (`"prerelease": true`, `"versioning": "prerelease"`, `"prerelease-type": "beta"`)
   and `target-branch` on the action.
2. GitHub never marks a prerelease as latest, so the default feed ignores it. Publish
   a second appcast for betas with `generate_appcast --channel beta`, and let testers
   opt in through `SPUUpdaterDelegate.allowedChannels(for:)` behind a setting.
