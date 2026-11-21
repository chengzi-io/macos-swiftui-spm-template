# Releasing

How to ship a version of the app, for the person who runs a release and accepts the
build. No code reading needed; every command runs from the repository root.

A **release** is a DMG on the GitHub Releases page plus an update feed, the **appcast**,
that installed copies read. A **draft** release is one only you can see: it has no tag
yet, the Releases page still shows the previous version, and nobody is offered the update
until you publish it.

## How a release runs

| Step | Who | Does what | What to check |
| --- | --- | --- | --- |
| 1 | you or your agent | writes the PR title, `feat: …` or `fix: …` | you understand the title, since users read it as a line of the notes; it follows Conventional Commits ([CONTRIBUTING](../.github/CONTRIBUTING.md)), and other types ship nothing |
| 2 | you | merges the PR; its title becomes the commit on `main` | CI is green |
| 3 | you | Actions → **Release** → **Run workflow**, branch `main`, `version` empty | or from a terminal: `gh workflow run release.yml` |
| 4 | CI | builds, signs and checks the app, then leaves a draft with the DMG, the dSYM zip, `appcast.xml` and `SHA256SUMS` | the run is green, and its summary links the draft |
| 5 | you | downloads the DMG from the draft's assets and accepts it | the checklist below passes |
| 6 | you | clicks **Publish release** | the tag `vX.Y.Z` appears, and installed copies are offered the update |

A **rejected draft** — a bug found in step 5, or notes you would rather not ship — is
fixed by a `fix:` PR and another run: the new run deletes the draft, builds the same
version number again and leaves a new draft. A draft has no tag, so nothing blocks it.

A run with only `chore:`, `docs:`, `ci:` and similar commits since the last release fails
in its first step with "nothing to release since vX.Y.Z". Nothing is wrong: those commits
ship nothing, so wait until a `feat` or `fix` is on `main`.

## Versions

The next version comes from the Conventional Commit titles since the last release:

| Commits since the last release | Version |
| --- | --- |
| a `feat` | minor: 1.4.2 → 1.5.0 |
| a `fix` | patch: 1.4.2 → 1.4.3 |
| a breaking change, below 1.0 | minor: 0.4.2 → 0.5.0 |
| only `docs`, `chore`, `ci`, `refactor`, `test`, … | nothing; the run stops |
| none yet, the first release | `0.1.0` |

The `version` input in step 3 takes an `X.Y.Z` you type and overrides that number: leave
it empty unless you mean a specific release, and it has to be higher than the last one
and not a tag that exists already.

`CFBundleVersion` is the number of commits on `main`, and that is what Sparkle compares:
it only grows, so an installed copy always sees a newer build. Dependabot opens security
updates as `fix(deps)`, which ship with the next release.

The Releases page is the changelog: each release's notes are its section, and there is no
`CHANGELOG.md` to edit.

## Before the first release

Once per app. `make status` says what is left: a `todo releases` line names the missing
step, and `ok releases` means the first release can run.

1. **`make github-settings`** creates the GitHub environment `release` and limits it to
   protected branches, so only a run from `main` can read its secrets.
2. **`make sparkle-key`** creates the Sparkle key — the key that signs every update, so an
   installed copy accepts an update from this app alone — in your login keychain, and
   writes its public half to `SUPublicEDKey` in `App/Configs/Info.plist`. Commit that file.
3. **Export the private half** to a file. `<bundle id>` is `BUNDLE_ID` in
   `App/Configs/Identity.xcconfig`; `make sparkle-key` prints this command with it filled
   in:

   ```bash
   ./.build/artifacts/sparkle/Sparkle/bin/generate_keys --account <bundle id> -x sparkle-private-key
   ```

4. **Back that file up offline**, in a password manager or on a USB drive, before you go
   on. The copy you give GitHub is no backup: a secret can be written, never read back or
   downloaded.
5. **Store it as the secret** `SPARKLE_ED_PRIVATE_KEY` in the `release` environment, then
   delete the file; the key stays in your login keychain and in the offline backup:

   ```bash
   gh secret set SPARKLE_ED_PRIVATE_KEY --env release < sparkle-private-key
   rm sparkle-private-key
   ```

6. **On a new Mac**, restore the backup; never create a new key there, because a new key
   is a different app to Sparkle and installed copies would reject every update.
   `make sparkle-key` refuses when `App/Configs/Info.plist` already has a key this Mac
   does not hold, and points at `RESTORE`:

   ```bash
   make sparkle-key RESTORE=<file>
   ```

### Ad-hoc or Developer ID

Ad-hoc builds are free and the default: on first launch macOS refuses the app, and the
release notes tell the user to click **Open Anyway** in System Settings → Privacy &
Security; a permission grant can also be asked again after an update.

With an Apple Developer Program membership, set `TEAM_ID` in
`App/Configs/Identity.xcconfig` and store these five secrets in the `release`
environment; the build then signs with the Developer ID and notarizes the DMG.

| Secret | Holds |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | your Developer ID Application certificate and its key, as a base64 `.p12` |
| `DEVELOPER_ID_P12_PASSWORD` | the password that `.p12` was exported with |
| `NOTARY_API_KEY_P8_BASE64` | your App Store Connect API key, as a base64 `.p8` |
| `NOTARY_API_KEY_ID` | that key's ID |
| `NOTARY_API_ISSUER_ID` | your App Store Connect issuer ID |

## Accepting the draft

Do this on the draft, before you publish: publishing ships it to everyone.

1. Download the DMG from the draft's assets on the Releases page (the run's summary links
   the draft) and open it.
2. Copy the app to a clean spot, `/Applications` or a fresh folder, and launch it. An
   ad-hoc build needs **Open Anyway** the first time (System Settings → Privacy &
   Security).
3. Open the app's Settings: the window opens, and **Check for Updates…** in it answers.
4. Walk every line of the release notes: each change works as it says it does.
5. Quit and launch it once more; nothing is asked a second time.
6. Click **Publish release**: it creates the tag `vX.Y.Z` at the built commit, and the
   release becomes the latest one.

Then test the update itself: install the previous version, open it, and **Check for
Updates…** in Settings offers the new one and installs it in place.

## When something goes wrong

| What you see | What to do |
| --- | --- |
| the run fails in its first step, on a secret or the key | the message names what is missing; add it ([before the first release](#before-the-first-release)) |
| the run fails anywhere else | fix what it names, then **Re-run failed jobs**: an outside cause (network, runner, notary service) clears up, and a rerun replaces the draft |
| the DMG fails the checklist | merge a `fix:` PR and run the workflow again |
| a published release is broken | mark the previous release **Latest**, then ship a `fix:` |

Marking the previous release **Latest** (edit the release, then **Set as the latest
release**) makes `releases/latest/download/appcast.xml` serve the previous appcast, so
Sparkle stops offering the broken update until the fix is out. A published tag never
moves or goes away: installed copies and links point at it.

## Symbolicating crashes

Each release carries its dSYM zip, `<App>-X.Y.Z.dSYM.zip`, and the run keeps it as the
artifact `dsym-v<version>` for 90 days. A crash report lists addresses; the dSYM turns
them back into function names:

```bash
atos -o <App>.app.dSYM/Contents/Resources/DWARF/<App> -arch arm64 -l <load address> <address>
```

`<App>` is the app's name, `APP_NAME` in `App/Configs/Identity.xcconfig`. On an
open-source repository the dSYM can stay public; for a closed-source app, remove it from
the assets `scripts/draft-release.sh` uploads and read the artifact instead.

## Beta channel

Not wired: a beta needs an appcast channel of its own, as
[Sparkle's channels](https://sparkle-project.org/documentation/publishing/#channels)
describes, and the template ships the stable feed alone.
