---
name: homebrew-cask
description: Put this app on Homebrew - in the official homebrew/cask, which keeps the cask up to date by itself once accepted, or in the user's own tap, which every release updates. The official cask needs a Developer ID and a notable repository; an own tap also takes ad-hoc builds, with a README warning.
disable-model-invocation: true
---

# Homebrew cask

Users install the app with `brew install --cask`. The app keeps updating itself through
Sparkle (`auto_updates true`); Homebrew only installs it.

## What this skill expects from the project

It is written for apps made from macos-swiftui-spm-template, once its init has run:

- `make release` writes `dist/$APP_NAME-$VERSION.dmg`. `.github/workflows/release.yml`
  has a `release-please` job and a `publish` job that publishes the GitHub Release, and
  the repository has a `release` environment.
- `App/Configs/Identity.xcconfig` sets `APP_NAME`, `APP_DISPLAY_NAME`, `BUNDLE_ID`,
  `TEAM_ID` and `GITHUB_REPOSITORY` as plain `KEY = value` lines; `scripts/common.sh`
  exports them, derives `RELEASES_URL` and defines `die` and `log`.
- `README.md` is the app's page for its users, with an Install section.
- `gh` is signed in to the user's GitHub account.

`<skill>` below is this skill's directory, for example `.agents/skills/homebrew-cask`.

## 1. Pick the channel

| | Official `homebrew/cask` | Own tap |
| --- | --- | --- |
| Users run | `brew install --cask <token>` | `brew install --cask <owner>/<name>/<token>` |
| Signing | Developer ID and notarized: Homebrew requires the app to pass Gatekeeper | Any; ad-hoc builds take scheme A or B (3.1) |
| Who gets in | A notable repository, at least 30 days old: 225 stars, 90 forks or 90 watchers when its own author submits it (75, 30 or 30 when someone else does) | Anyone |
| New versions | Homebrew's BrewTestBot checks every 3 hours and opens the update pull request itself; the release workflow does nothing | A job in the release workflow pushes the cask |
| One-time work | A pull request to `Homebrew/homebrew-cask` that the user reviews and answers for | A tap repository and a token |

Read the facts before recommending one:

```bash
grep '^TEAM_ID' App/Configs/Identity.xcconfig
gh repo view --json stargazerCount,forkCount,watchers,createdAt
gh release list --exclude-drafts --limit 1
```

- `TEAM_ID` empty: own tap, scheme A or B.
- Developer ID, but the repository is not notable yet: own tap with scheme C now, the
  official cask later (step 4).
- Developer ID and notable: the official cask. No tap, no token, no workflow change.

## 2. Official `homebrew/cask`

Homebrew accepts pull requests written with AI on these terms; tell the user before
starting:

- The pull request says that AI was used, and which tool.
- The user reviews everything before asking maintainers to review it.
- No commit names AI as author or co-author, and no `Assisted-by` or similar trailer.
- The user answers maintainers' questions and review comments themselves.

Forking, pushing and opening the pull request act on the user's GitHub account: ask
before each.

1. Write the cask. `brew generate-cask-token "<path to the .app>"` gives the token. Take
   the values from `App/Configs/Identity.xcconfig`, `version.txt` and the DMG of the latest published
   release (`gh release download v<version> --pattern '*.dmg' --dir .build/cask`, then
   `shasum -a 256`):

   ```ruby
   cask "<token>" do
     version "<version>"
     sha256 "<sha256 of the DMG>"

     url "https://github.com/<owner>/<repo>/releases/download/v#{version}/<APP_NAME>-#{version}.dmg"
     name "<APP_DISPLAY_NAME>"
     desc "<what the app is, in a few plain words>"
     homepage "https://github.com/<owner>/<repo>"

     livecheck do
       url :url
       strategy :github_latest
     end

     auto_updates true
     depends_on macos: :<minimum macOS, for example sonoma>

     app "<APP_NAME>.app"

     zap trash: [
       "~/Library/Application Scripts/<BUNDLE_ID>",
       "~/Library/Containers/<BUNDLE_ID>",
     ]
   end
   ```

   - `desc`: ask the user what the app is, then follow Homebrew's Description
     Guidelines: a neutral one-liner, without the app's name or marketing words.
   - `livecheck`: release-please creates the tag while the release is still a draft, so
     the default strategy, which reads tags, can see a version whose DMG cannot be
     downloaded yet. `:github_latest` reads only published releases.

2. Check it in a checkout of `homebrew/cask`, in `Casks/<first letter of token>/`:

   ```bash
   brew tap --force homebrew/cask
   cd "$(brew --repository homebrew/cask)"
   git checkout -b <token> origin/HEAD
   cp <cask file> Casks/<letter>/<token>.rb
   HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask <token>
   brew uninstall --cask <token>
   brew audit --new --cask <token>
   brew style --fix --cask <token>
   brew lgtm --online
   ```

   `brew audit --new` also checks the repository's notability and the download.
3. With the user's go-ahead: fork (`gh repo fork Homebrew/homebrew-cask --clone=false`),
   `git remote add <user> https://github.com/<user>/homebrew-cask.git`, commit as
   `<token> <version> (new cask)` with no AI trailer, push, and open the pull request:
   fill in its template and disclose the AI use. Then the user follows up with the
   maintainers.
4. In the project, once the pull request is merged:
   - `README.md`, in the Install section after the DMG instructions:

     ````markdown
     With [Homebrew](https://brew.sh):

     ```bash
     brew install --cask <token>
     ```
     ````

   - `docs/RELEASING.md`: replace the `## Homebrew cask (optional)` section, which only
     points to this skill, with `<skill>/wiring/releasing-official.md`.
   - Nothing changes in the release workflow or `App/Configs/Identity.xcconfig`. Commit, for example
     `docs: add the homebrew install`.

## 3. Own tap

### 3.1 How the cask meets Gatekeeper

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
  Gatekeeper, can later go to `homebrew/cask`, and Sparkle updates keep the app's
  permissions.

`scripts/update-cask.sh` decides on every release: C as soon as `TEAM_ID` is set,
otherwise `HOMEBREW_UNSIGNED` (`caveats` or `xattr`).

### 3.2 What the user sets up

1. A tap repository named `homebrew-<name>`, for example `<owner>/homebrew-tap`, with a
   `Casks/` directory. Users then install with
   `brew install --cask <owner>/<name>/<token>`; the token is `APP_NAME` in lower case.
2. A fine-grained token with Contents read and write on the tap only, stored in the
   `release` environment: `gh secret set HOMEBREW_TAP_TOKEN --env release`.

Both need the user's GitHub account: ask before creating either for them.

### 3.3 Wire it in

1. `cp <skill>/wiring/update-cask.sh scripts/update-cask.sh`
2. At the end of `App/Configs/Identity.xcconfig`, in its `KEY = value` form:

   ```text
   // Homebrew tap the release workflow updates (owner/homebrew-name).
   HOMEBREW_TAP = <owner>/homebrew-<name>
   // Ad-hoc builds only (TEAM_ID empty): caveats or xattr; see scripts/update-cask.sh.
   HOMEBREW_UNSIGNED = <caveats or xattr; empty with a Developer ID>
   ```

3. In `.github/workflows/release.yml`, a job after `publish`, with the runner and
   `DEVELOPER_DIR` the publish job uses:

   ```yaml
     homebrew:
       name: Update Homebrew cask
       # Runs once the release is public, so a failure here leaves the publish job green
       # (red there means "still a draft") and can be re-run on its own.
       needs: [release-please, publish]
       runs-on: <the publish job's runner>
       timeout-minutes: 15
       environment: release
       env:
         DEVELOPER_DIR: <the publish job's DEVELOPER_DIR>
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
   points to this skill, with `<skill>/wiring/releasing-tap.md`.
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

### 3.4 Check and finish

1. After `make release` (it needs `SUPublicEDKey` in `App/Configs/Info.plist`), write the cask and check its
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

3. `make ci`, then commit `scripts/update-cask.sh`, `App/Configs/Identity.xcconfig`, the workflow job,
   `README.md` and `docs/RELEASING.md` together, for example
   `feat(homebrew): publish releases to a homebrew tap`.

Once `TEAM_ID` is set, the next release's cask is plain. Remove `HOMEBREW_UNSIGNED` and
the README notice; `update-cask.sh` logs a reminder while `HOMEBREW_UNSIGNED` remains.

## 4. From the own tap to `homebrew/cask`

When the app has a Developer ID and the repository is notable, submit it as in step 2.
After the merge:

- In the project, remove the `homebrew` job, `scripts/update-cask.sh`, `HOMEBREW_TAP` and
  `HOMEBREW_UNSIGNED`, and switch `README.md` and `docs/RELEASING.md` to the official
  text from step 2.
- In the tap, delete `Casks/<token>.rb` and add `"<token>": "homebrew/cask"` to its
  `tap_migrations.json`, so `brew install --cask <owner>/<name>/<token>` installs the
  official cask.
- Homebrew does not move copies already installed from the tap; they keep updating
  through Sparkle. Tell users who want Homebrew to track the official cask to run
  `brew uninstall --cask <owner>/<name>/<token> && brew install --cask <token>`.
