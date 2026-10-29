---
name: release-setup
description: Walk the user through the one-time release setup of this repository - GitHub settings and branch protection, the GitHub App for release-please, the Sparkle signing key, and optionally a Developer ID - checking what is already done. Use when the user asks to set up releases, after init, on a new Mac, or to rotate a key.
disable-model-invocation: true
---

# Release setup

Gets a repository from "the Release workflow skips with a notice" to "merging a release
PR publishes a DMG and an appcast". How a release runs once this is done:
[docs/RELEASING.md](../../../docs/RELEASING.md).

`<skill>` is this skill's directory, `.agents/skills/release-setup`; its scripts run from
anywhere inside the project. `<App>` is `APP_NAME` in `App/Configs/Identity.xcconfig`.

## Ground rules

- The accounts are the user's. You run read-only checks and the two scripts; the user
  creates the App, keys and certificates, and types every secret into `gh` themselves.
- Never print, log, commit or paste a secret's value, and never ask for one in chat.
  Exported key files go in the repository root only for as long as a step needs them
  (`.gitignore` covers them), then the user deletes them.
- Do one step at a time, and confirm before each step that changes GitHub settings.
- Rerun `<skill>/scripts/check.sh` before step 1 and after each step: it reports `ok`
  or `todo` per item, so a setup that stopped resumes where it was.

## Before you start

- `main` is on GitHub and `make ci` passes; `gh auth status` shows a login with admin
  rights on the repository; `GITHUB_REPOSITORY` in `Identity.xcconfig` names it.
- Ask whether releases will be ad-hoc (default, free) or Developer ID signed (Apple
  Developer Program); show the table in
  [references/developer-id.md](references/developer-id.md#what-users-get) if unsure.

## 1. Repository settings

```bash
<skill>/scripts/github-setup.sh
```

Squash merge only, with the PR title as the commit title; `main` requires a PR and the
three checks below; the workflow token is read-only; the `release` environment only
runs from protected branches; private vulnerability reporting is on. It prints the
settings it reads back.

| Required check | Your PRs | Release PR |
| --- | --- | --- |
| `Validate PR title` | runs | skipped |
| `Lint, test, build` | runs | skipped |
| `Lint scripts and workflows` | runs | runs, passes |

A skipped required check counts as passed: release-please's PRs (branch
`release-please--*`, opened by its App as a Bot) skip the first two.

Tell the user, before running it: **from now on `main` only takes pull requests,
admins included** (`enforce_admins: true`). A direct `git push origin main` is
rejected, so every later change, the commits of steps 3 and 4 too, goes through a
branch and a PR.

The checks stop mistakes, not someone set on getting past them: a PR can rewrite its
own workflow, and an admin can lift the protection. A token that can push a branch can
merge it too, so an agent holding the user's token can merge work they never saw. To
prevent that, give the agent no write access (it commits; the user pushes and merges),
or a GitHub account of its own and rerun the script: with two or more pushers `main`
needs an approving review, and nobody approves their own PR.

## 2. GitHub App for release-please

A PR opened with the default `GITHUB_TOKEN` starts no workflows, so its required
checks never report and it can never merge; release-please therefore runs on a GitHub
App token. The user does this in the browser:

1. GitHub → Settings → Developer settings → GitHub Apps → New GitHub App. Webhook
   off. Repository permissions: Contents read and write, Pull requests read and write.
2. Generate a private key, then install the App on this repository only.
3. Store the client ID and key (the user runs these):

   ```bash
   gh variable set RELEASE_APP_CLIENT_ID --body "<client id>"
   gh secret set RELEASE_APP_PRIVATE_KEY --env release < release-app.private-key.pem
   rm release-app.private-key.pem
   ```

The key can write to every repository the App is installed on: one App per repository,
or one App only for repositories with the same maintainers.

## 3. Sparkle signing key

```bash
<skill>/scripts/sparkle-keys.sh
```

Creates an EdDSA key in the login keychain (account = bundle identifier), or reuses
it, writes the public key to `SUPublicEDKey` in `App/Configs/Info.plist`, and prints
the commands that export the private key and store it as `SPARKLE_ED_PRIVATE_KEY` in
the `release` environment. The user runs those, and backs the exported key up offline
before deleting it: without it, installed copies can never update again. Commit the
`Info.plist` change on a branch and open a PR. Release builds fail while
`SUPublicEDKey` is empty.

On a new Mac, import the backed-up key with
`.build/artifacts/sparkle/Sparkle/bin/generate_keys --account <bundle id> -f <file>`;
never generate a second key for a shipped app.

## 4. Signing

- **Ad-hoc (default):** leave `TEAM_ID` empty in `App/Configs/Identity.xcconfig`.
  Nothing else to do; the publish job adds a first-launch note to each release.
- **Developer ID:** follow [references/developer-id.md](references/developer-id.md):
  certificate, notary API key, `TEAM_ID` and five secrets.

## 5. First release

1. `check.sh` shows no `todo`.
2. Merge a `feat:` or `fix:` PR; release-please opens a release PR. The user reviews
   and squash-merges it.
3. Watch the Release workflow: `gh run watch`. When it passes, the GitHub Release has
   the DMG, dSYM zip, `appcast.xml` and `SHA256SUMS`; download the DMG and open it.
4. A failure leaves a draft release: [Recovering](../../../docs/RELEASING.md#recovering-from-a-failed-or-bad-release).

## Never

- create, change or delete the user's GitHub App, Apple account, certificates or
  secrets yourself, or read a secret's value
- push to `main` or merge the release PR for the user
- generate a new Sparkle key for an app that has shipped: installed copies would reject
  every update
