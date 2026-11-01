---
name: setup-releases
description: Install and finish this app's release pipeline - the wiring (release workflow, release-please, release scripts, docs), the release environment, the GitHub App for release-please, the Sparkle signing key, and the first release, 0.1.0. Use when the user asks to set up releases or to ship, or on a new Mac to restore the Sparkle key.
disable-model-invocation: true
---

# Setup releases

Gets the app from "no release pipeline" to "merging a release PR publishes a DMG and an
appcast". How a release then runs: `docs/RELEASING.md`, which step 1 installs.
`<skill>` is `.agents/skills/setup-releases`; its scripts run from anywhere inside the
project. `<App>` is `APP_NAME` in `App/Configs/Identity.xcconfig`.

## Status

Moves the `make status` releases line from `--` (not set up) to `todo` while a step is
left, then to `ok`. Once step 1 is done, `scripts/release-status.sh` prints one `ok` or
`todo` line per step; `make status` shows its first `todo`.

## Before you start

- `make status`: the project and repo lines are `ok` (`main` pushed and protected) and
  `make ci` passes.
- `gh auth status` shows a login with admin rights on the repository that
  `GITHUB_REPOSITORY` in `App/Configs/Identity.xcconfig` names.
- Ask whether releases will be ad-hoc (default, free) or Developer ID signed (Apple
  Developer Program); the `setup-developer-id` skill explains what users get with each.

## Plan

One message: what step 1 writes into the repository (`## Changes`), that steps 2 to 4
change GitHub and the login keychain, and which signing the user picked. Show the
`install.sh --dry-run` output, and wait for the go-ahead before each step that changes
GitHub.

## Steps

### 1. Install the pipeline

```bash
<skill>/scripts/install.sh --dry-run   # what would change
<skill>/scripts/install.sh             # copies it; stops on a file that differs
```

It copies every file under `<skill>/wiring/` to the same path in the app: the workflow,
release-please's config and manifest, the release scripts, `release.mk` (the Makefile
includes it) and `docs/RELEASING.md`. It puts the Install and Update sections into
`README.md` before `## Feedback`. A second run says `done already`; a file that differs
stops it with a diff to merge by hand. Commit on a branch and open a PR:
`chore: install the release pipeline` releases nothing.

### 2. The release environment

```bash
<skill>/scripts/release-environment.sh
```

It limits the `release` environment, which holds the secrets of steps 3 and 4, to
protected branches, and prints the policy it reads back. It refuses while `main` is not
protected: run `make github-settings` first, with the user's go-ahead.

A skipped required check counts as passed, so release-please's PRs (branch
`release-please--*`, opened by its App as a Bot) can merge:

| Required check | Your PRs | Release PR |
| --- | --- | --- |
| `Validate PR title` | runs | skipped |
| `Lint, test, build` | runs | skipped |
| `Lint scripts and workflows` | runs | runs, passes |

### 3. GitHub App for release-please

A PR opened with the default `GITHUB_TOKEN` starts no workflows, so its required checks
never report and it can never merge; release-please runs on a GitHub App token instead.

```bash
xcrun swift <skill>/scripts/create-app.swift
```

The browser opens GitHub's Create GitHub App page, filled in: no webhook, Contents and
Pull requests read and write. The user clicks **Create GitHub App**, then on the install
page picks **Only select repositories**, this one, and clicks **Install**. The script
stores the client ID as the variable `RELEASE_APP_CLIENT_ID` and the private key as the
`release` environment's secret `RELEASE_APP_PRIVATE_KEY`; the key never touches the disk.
The key can write to every repository the App is installed on: one App per repository.

### 4. Sparkle signing key

The Sparkle key signs each update, so installed copies accept only the app's own.

```bash
<skill>/scripts/sparkle-keys.sh create          # or, on a new Mac: restore FILE
```

`create` makes an EdDSA key in the login keychain (account = bundle identifier), or
reuses it; `restore FILE` imports a backup. Either writes the public key to
`SUPublicEDKey` in `App/Configs/Info.plist` and prints the commands that export the
private key and store it as `SPARKLE_ED_PRIVATE_KEY`. The user runs those, and backs the
exported key up offline before deleting it: without it, installed copies can never
update again. Commit the `Info.plist` change on a branch and open a PR.

### 5. Signing

- **Ad-hoc (default):** leave `TEAM_ID` empty. The publish job adds a first-launch note
  to each release, and `README.md` has one.
- **Developer ID:** the `setup-developer-id` skill, after this one.

### 6. First release

1. `scripts/release-status.sh` shows no `todo`.
2. Merge a `feat:` or `fix:` PR; release-please opens a release PR for **0.1.0**, which
   the user squash-merges.
3. Watch the Release workflow: `gh run watch`. When it passes, the GitHub Release has
   the DMG, dSYM zip, `appcast.xml` and `SHA256SUMS`; download the DMG and open it.
4. A failure leaves a draft release: `docs/RELEASING.md`, Recovering.

## Changes

- Files: `.github/workflows/release.yml`, `.github/release-please-config.json`,
  `.release-please-manifest.json`, `release.mk`, `docs/RELEASING.md`,
  `scripts/{release,release-status,package-dmg,notarize,appcast,verify-dmg,publish-github,ci-keychain}.sh`,
  `scripts/verify-appcast.swift`, the Install and Update sections of `README.md`, and
  `SUPublicEDKey` in `App/Configs/Info.plist`.
- GitHub: the `release` environment and its branch policy, the GitHub App, the variable
  `RELEASE_APP_CLIENT_ID` and the environment's secrets.
- This Mac: the Sparkle key in the login keychain.

## The user's part

- Click Create and Install for the GitHub App.
- Export, back up and store the Sparkle key; type every other secret into `gh`.
- Merge the PRs and the release PR.

## Done when

- `scripts/release-status.sh` shows no `todo`, and `make status` shows `ok releases`.
- The first release is published, and its DMG opens and launches.

## Never

- create, change or delete the user's GitHub App, Apple account, certificates or
  secrets outside the scripts, or read a secret's value
- print, log, commit or paste a secret; an exported key file stays in the repository
  root only while a step needs it, then the user deletes it
- push to `main`, or merge a PR or the release PR for the user
- generate a new Sparkle key for an app that has shipped: installed copies would reject
  every update
- change GitHub settings without the user's go-ahead, or run two steps at once
