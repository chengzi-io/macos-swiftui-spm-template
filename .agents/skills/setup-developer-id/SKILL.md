---
name: setup-developer-id
description: Walk the user through signing releases with a Developer ID and notarizing them - the Apple Developer Program certificate, the notary API key, TEAM_ID and the five secrets - so Gatekeeper opens the app. Use when the user asks for Developer ID signing, notarization, or to replace ad-hoc releases.
disable-model-invocation: true
---

# Developer ID signing

Goal: releases signed with a Developer ID and notarized by Apple, so the DMG opens
without the Open Anyway detour and permissions survive updates.

`<skill>` is this skill's directory, `.agents/skills/setup-developer-id`. `<App>` is
`APP_NAME` in `App/Configs/Identity.xcconfig`.

## Status

Moves the `signing` line of `make status` from `-- ad-hoc (optional)` to
`ok Developer ID, team <TEAM_ID>`.

What changes for users: [references/what-users-get.md](references/what-users-get.md).

## Before you start

- The `releases` line of `make status` is `ok`: the release pipeline is installed
  (`setup-releases`). The `signing` line is `--`.
- `gh auth status` shows a login with admin rights on the repository;
  `GITHUB_REPOSITORY` in `App/Configs/Identity.xcconfig` names it; Xcode 26.2 is
  installed.
- The user has an Apple Developer Program membership and the Account Holder role: only
  they create the certificate and the keys.
- Keep the Sparkle key: installed copies accept the first Developer ID update by its
  EdDSA signature, so never generate a second one
  ([references/moving-from-ad-hoc.md](references/moving-from-ad-hoc.md)).

## Plan

Show the user this plan and wait for the go-ahead before the first step.

1. The Developer ID Application certificate, exported as a `.p12`.
2. The App Store Connect notary key.
3. `TEAM_ID` into `App/Configs/Identity.xcconfig`, on a branch and a PR.
4. The five secrets in the `release` environment.
5. The notary credentials for local releases.
6. A check that the next release is notarized.
7. The `### First launch` subsection leaves `README.md`.

## Steps

### 1. The certificate (the user)

1. Join the Apple Developer Program.
2. Create a **Developer ID Application** certificate: Xcode → Settings → Accounts →
   Manage Certificates, as Account Holder.
3. Export it with its private key from Keychain Access as a `.p12`, with a password.

### 2. The notary API key (the user)

App Store Connect → Users and Access → Integrations → App Store Connect API: create a
team key with the Developer role, download the `.p8` once, and note the key ID and the
issuer ID.

### 3. `TEAM_ID`

Set `TEAM_ID` in `App/Configs/Identity.xcconfig`, commit it on a branch and open a PR.
With `TEAM_ID` set, a missing certificate or notary secret fails the release instead of
falling back to ad-hoc.

### 4. The five secrets (the user)

The exported files sit in the repository root only while this step needs them
(`.gitignore` covers them). The user runs these there, then deletes the files:

```bash
base64 -i developer-id.p12 | gh secret set DEVELOPER_ID_P12_BASE64 --env release
gh secret set DEVELOPER_ID_P12_PASSWORD --env release
base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set NOTARY_API_KEY_P8_BASE64 --env release
gh secret set NOTARY_API_KEY_ID --env release --body XXXXXXXXXX
gh secret set NOTARY_API_ISSUER_ID --env release --body <issuer uuid>
```

The publish job imports them into a temporary keychain and deletes it when the job ends.

### 5. Local releases (the user)

Keep the certificate in the login keychain, and store the notary credentials once:

```bash
xcrun notarytool store-credentials notary --key AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX --issuer <issuer uuid>
NOTARY_PROFILE=notary make release
```

`make doctor` checks for the certificate on this Mac.

### 6. Check a notarized build

After the first release:

```bash
spctl --assess --type execute -vv dist/<App>.app          # source=Notarized Developer ID
spctl -a -t open --context context:primary-signature -vv dist/<App>-X.Y.Z.dmg
xcrun stapler validate dist/<App>-X.Y.Z.dmg
```

### 7. Remove the first-launch note from `README.md`

A signed, notarized build opens without it, so the `### First launch` subsection goes:
its heading and its paragraph, up to the next heading.

```bash
awk '/^### First launch$/ { skip = 1; next } skip && /^#/ { skip = 0 } !skip' \
    README.md >README.md.new && mv README.md.new README.md
grep -n '### First launch' README.md
```

The `grep` prints nothing once the subsection is gone. Commit the `README.md` change
with the `TEAM_ID` one or on its own.

## Changes

| File or setting | What changes |
| --- | --- |
| `App/Configs/Identity.xcconfig` | `TEAM_ID = <team id>` |
| `release` environment | `DEVELOPER_ID_P12_BASE64`, `DEVELOPER_ID_P12_PASSWORD`, `NOTARY_API_KEY_P8_BASE64`, `NOTARY_API_KEY_ID`, `NOTARY_API_ISSUER_ID` |
| `README.md` | the `### First launch` subsection is removed |
| the login keychain | the certificate, for local releases |
| `.github/workflows/release.yml` | nothing: it imports the secrets when `TEAM_ID` is set |

## The user's part

- The Apple Developer Program membership and the Account Holder role; the **Developer ID
  Application** certificate and its `.p12`; the App Store Connect team key and its
  `.p8`; every secret typed into `gh`; `notarytool store-credentials`.
- Deleting the exported `.p12` and `.p8` once the secrets are stored.

## Done when

1. `make status`: the `signing` line is `ok Developer ID, team <TEAM_ID>`.
2. The next release passes `spctl --assess --type execute -vv` with
   `source=Notarized Developer ID`, and `xcrun stapler validate` on its DMG.
3. `grep -n '### First launch' README.md` prints nothing, and `make ci` passes.

## Never

- create the certificate, the App Store Connect key or the secrets for the user, or read
  a secret's value
- commit the `.p12`, the `.p8` or their passwords
- generate a new Sparkle key for an app that has shipped: installed copies would reject
  every update
- push or merge the `TEAM_ID` PR for the user
