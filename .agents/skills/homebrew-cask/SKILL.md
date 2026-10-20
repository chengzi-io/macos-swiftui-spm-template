---
name: homebrew-cask
description: Publish this app to the user's Homebrew tap - every release writes the cask from its DMG and pushes it. With a Developer ID the cask is plain; for ad-hoc builds the user picks a cask that explains Open Anyway or one that clears quarantine, and README.md warns about either.
disable-model-invocation: true
---

# Homebrew cask

Users install the app with `brew install --cask <owner>/<tap>/<token>`, and every
release updates the cask in the user's own tap. The app keeps updating itself through
Sparkle (`auto_updates true`); Homebrew only installs it.

## What this skill expects from the project

It is written for apps made from macos-swiftui-spm-template, after `scripts/init.sh`:

- `make release` writes `dist/$APP_NAME-$VERSION.dmg`. `.github/workflows/release.yml`
  has a `release-please` job and a `publish` job that publishes the GitHub Release, and
  the repository has a `release` environment.
- `Bundle/app.env` sets `APP_NAME`, `APP_DISPLAY_NAME`, `BUNDLE_ID`, `TEAM_ID` and
  `RELEASES_URL`; `scripts/common.sh` loads it and defines `die` and `log`.
- `README.md` is the app's page for its users, with an Install section.

`<skill>` below is this skill's directory, for example `.agents/skills/homebrew-cask`.

## 1. Pick how the cask meets Gatekeeper

Homebrew quarantines what it downloads, so macOS checks the app on its first launch.

| Scheme | When | The cask | README.md |
| --- | --- | --- | --- |
| C. Developer ID | `TEAM_ID` is set | Plain: the app passes the check and opens | The install command |
| A. caveats | Ad-hoc, the user picks it | Tells users to click Open Anyway after macOS blocks the first launch | The command and notice A |
| B. xattr | Ad-hoc, the user picks it | Clears the quarantine flag after installing, so macOS never checks the app | The command and notice B |

With `TEAM_ID` set, use C. With it empty, explain the trade-off and let the user pick A
or B:

- A: users get stuck at the first launch, as they do with the DMG.
- B: users notice nothing, but the author answers for skipping Gatekeeper, and
  `homebrew/cask` never accepts such a cask.
- C, for comparison: the Apple Developer Program costs $99 a year; the cask then passes
  Gatekeeper, can be submitted to `homebrew/cask`, and Sparkle updates keep the app's
  permissions.

`scripts/update-cask.sh` decides on every release: C as soon as `TEAM_ID` is set,
otherwise `HOMEBREW_UNSIGNED` (`caveats` or `xattr`).

## 2. What the user sets up

1. A tap repository named `homebrew-<name>`, for example `<owner>/homebrew-tap`, with a
   `Casks/` directory. Users then install with
   `brew install --cask <owner>/<name>/<token>`; the token is `APP_NAME` in lower case.
2. A fine-grained token with Contents read and write on the tap only, stored in the
   `release` environment: `gh secret set HOMEBREW_TAP_TOKEN --env release`.

Both need the user's GitHub account: ask before creating either for them.

## 3. Wire it in

1. `cp <skill>/wiring/update-cask.sh scripts/update-cask.sh`
2. At the end of `Bundle/app.env`:

   ```bash
   # Homebrew tap the release workflow updates (owner/homebrew-name).
   HOMEBREW_TAP=<owner>/homebrew-<name>
   # Ad-hoc builds only (TEAM_ID empty): caveats or xattr; see scripts/update-cask.sh.
   HOMEBREW_UNSIGNED=<caveats or xattr; empty with a Developer ID>
   ```

3. In `.github/workflows/release.yml`, a job after `publish`, with the runner and
   `DEVELOPER_DIR` the publish job uses:

   ```yaml
     homebrew:
       name: Update Homebrew cask
       # Runs once the release is public, so a failure here leaves the publish job green
       # (red there means "still a draft") and can be re-run on its own.
       needs: [release-please, publish]
       runs-on: macos-26
       timeout-minutes: 15
       environment: release
       env:
         DEVELOPER_DIR: /Applications/Xcode_26.2.app/Contents/Developer
         TAG: ${{ needs.release-please.outputs.tag_name }}
       steps:
         - uses: actions/checkout@v7
           with:
             ref: ${{ needs.release-please.outputs.tag_name }}
         - name: Download the published DMG
           env:
             GH_TOKEN: ${{ github.token }}
           run: gh release download "$TAG" --pattern '*.dmg' --dir dist
         - name: Push the cask to the tap
           env:
             GH_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
           run: scripts/update-cask.sh push
   ```

4. In `docs/RELEASING.md`, replace the `## Homebrew cask (optional)` section, which only
   points to this skill, with `<skill>/wiring/releasing.md`.
5. In `README.md`'s Install section, after the DMG instructions:

   ````markdown
   With [Homebrew](https://brew.sh):

   ```bash
   brew install --cask <owner>/<name>/<token>
   ```
   ````

   For A, follow it with:

   ```markdown
   > [!IMPORTANT]
   > <App> is not signed with an Apple Developer ID yet. After `brew install`, macOS
   > blocks its first launch: open System Settings → Privacy & Security and click
   > **Open Anyway**, once.
   ```

   For B:

   ```markdown
   > [!IMPORTANT]
   > <App> is not signed with an Apple Developer ID or notarized by Apple. Its Homebrew
   > cask removes the quarantine flag macOS puts on downloads, so macOS opens the app
   > without checking it. Install it this way only if you trust this repository; the
   > DMG above keeps the check.
   ```

## 4. Check and finish

1. After `make release` (it needs `SPARKLE_PUBLIC_KEY`), write the cask and check its
   syntax: `scripts/update-cask.sh print > .build/<token>.rb && ruby -c .build/<token>.rb`.
2. With Homebrew installed, check it as Homebrew will, in a throwaway local tap; outside
   a tap `brew style` applies other rules:

   ```bash
   export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
   brew tap-new local/casktest --no-git
   mkdir -p "$(brew --repository local/casktest)/Casks"
   cp .build/<token>.rb "$(brew --repository local/casktest)/Casks/"
   brew style "$(brew --repository local/casktest)/Casks/<token>.rb"
   brew audit --cask local/casktest/<token>
   brew untrust --cask local/casktest/<token>; brew untap local/casktest
   ```

3. `make ci`, then commit `scripts/update-cask.sh`, `Bundle/app.env`, the workflow job,
   `README.md` and `docs/RELEASING.md` together, for example
   `feat(homebrew): publish releases to a homebrew tap`.

## Later: a Developer ID

Once `TEAM_ID` is set, the next release's cask is plain. Remove `HOMEBREW_UNSIGNED` and
the README notice; `update-cask.sh` logs a reminder while `HOMEBREW_UNSIGNED` remains.
