---
name: setup-homebrew
description: Put this app on Homebrew - in the official homebrew/cask, which keeps the cask up to date by itself once accepted, or in the user's own tap, which every release updates. The official cask needs a Developer ID and a notable repository; an own tap also takes ad-hoc builds, with a README warning.
disable-model-invocation: true
---

# Homebrew cask

Goal: users install the app with `brew install --cask`; the app keeps updating itself
through Sparkle (`auto_updates true`), and Homebrew only installs it.

`<skill>` is this skill's directory, `.agents/skills/setup-homebrew`. `<App>` is
`APP_NAME` in `App/Configs/Identity.xcconfig`; `<token>` is `APP_NAME` in lower case.

## Status

Moves the `homebrew` line of `make status` from
`-- not set up (optional, after the first release)` to
`ok every release updates the own tap`, which it reads from `scripts/update-cask.sh`.

The official cask changes nothing in the repository, so that line stays `--`: Homebrew's
BrewTestBot updates the cask.

## Before you start

- The `releases` line of `make status` is `ok` (`setup-releases`), and there is a
  published release: `gh release list --exclude-drafts --limit 1`.
- The official cask also needs the `signing` line `ok` (`setup-developer-id`): Homebrew
  requires the app to pass Gatekeeper.
- `App/Configs/Identity.xcconfig` sets `APP_NAME`, `APP_DISPLAY_NAME`, `BUNDLE_ID`,
  `TEAM_ID` and `GITHUB_REPOSITORY` as plain `KEY = value` lines; `scripts/common.sh`
  exports them, derives `RELEASES_URL` and defines `die` and `log`.
- `make release` writes `dist/<App>-<version>.dmg`; `.github/workflows/release.yml` has
  the `release-please` and `publish` jobs; the repository has a `release` environment.
- `README.md` is the app's page for its users, with an Install section.
- `gh auth status` shows the user's GitHub account; `brew` is installed for the checks.

## Plan

Show the user this plan and wait for the go-ahead: step 1 picks the channel, and steps 2
and 3 to 5 differ per channel.

1. Read the facts, recommend a channel.
2. Official cask: cask, checks, pull request, then the README and `docs/RELEASING.md`.
3. Own tap: the user's repository and token, then the wiring.
4. Own tap: check the cask, commit.
5. Later: from the own tap to the official cask.

## Steps

### 1. Read the facts and pick the channel

| | Official `homebrew/cask` | Own tap |
| --- | --- | --- |
| Users run | `brew install --cask <token>` | `brew install --cask <owner>/<name>/<token>` |
| Signing | Developer ID and notarized: Homebrew requires the app to pass Gatekeeper | Any; ad-hoc builds take scheme A or B |
| Who gets in | A notable repository, at least 30 days old | Anyone |
| New versions | BrewTestBot checks every 3 hours and opens the update pull request itself; the release workflow does nothing | A job in the release workflow pushes the cask |
| One-time work | A pull request the user reviews and answers for | A tap repository and a token |

```bash
grep '^TEAM_ID' App/Configs/Identity.xcconfig
gh repo view --json stargazerCount,forkCount,watchers,createdAt
gh release list --exclude-drafts --limit 1
```

- `TEAM_ID` empty: own tap, scheme A or B.
- Developer ID, but the repository is not notable yet: own tap with scheme C now, the
  official cask later (step 5).
- Developer ID and notable: the official cask. No tap, no token, no workflow change.

### 2. Official cask

Follow [references/official-cask.md](references/official-cask.md). Ask the user before
each step that acts on their GitHub account.

### 3. Own tap: the user's part

Follow [references/own-tap.md](references/own-tap.md#what-the-user-sets-up). Ask before
creating anything in their account.

### 4. Own tap: wire it in and check it

Follow [references/own-tap.md](references/own-tap.md#wire-it-in), then
[references/own-tap.md](references/own-tap.md#check-and-finish). The Gatekeeper schemes
that decide the cask and the README notice:
[references/own-tap.md](references/own-tap.md#how-the-cask-meets-gatekeeper).

### 5. Later: from the own tap to the official cask

Follow [references/official-cask.md](references/official-cask.md#from-the-own-tap).

## Changes

| File or setting | Official `homebrew/cask` | Own tap |
| --- | --- | --- |
| `README.md` | the install command | the install command, plus a notice for an ad-hoc cask |
| `docs/RELEASING.md` | `wiring/releasing-official.md` | `wiring/releasing-tap.md` |
| `.github/workflows/release.yml` | nothing | a `homebrew` job after `publish` |
| `App/Configs/Identity.xcconfig` | nothing | `HOMEBREW_TAP`, and `HOMEBREW_UNSIGNED` while ad-hoc |
| `scripts/update-cask.sh` | nothing | copied from `wiring/` |
| `release` environment | nothing | `HOMEBREW_TAP_TOKEN` |
| a tap repository | nothing | the user's |

## The user's part

- The GitHub account: the fork and the pull request for the official cask; the tap
  repository and its token for the own tap.
- Reviewing the submission in their name, and answering Homebrew's maintainers.
- The Developer ID itself is `setup-developer-id`; nothing here creates a certificate.

## Done when

1. `make ci` passes; the own tap changes are committed on a branch, the official cask is
   a merged pull request.
2. Own tap: the next release's `homebrew` job is green,
   `brew install --cask <owner>/<name>/<token>` works, and `make status` shows
   `ok homebrew`.
3. Official cask: `brew install --cask <token>` works after the merge; `make status`
   still shows `-- homebrew`, since nothing in the repository changed.

## Never

- create the tap repository, the token or the fork yourself, or push to the user's
  account without asking
- name AI as author or co-author of a commit to the official cask, or add an
  `Assisted-by` trailer
- ask the maintainers to review before the user has reviewed the submission
- submit an ad-hoc cask to the official `homebrew/cask`: it never passes the Gatekeeper
  check
