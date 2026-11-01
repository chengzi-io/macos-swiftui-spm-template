# Official `homebrew/cask`

Users run `brew install --cask <token>`. The cask keeps itself up to date: Homebrew's
BrewTestBot checks the latest published GitHub release every 3 hours and opens the
update pull request itself, so the release workflow does nothing for Homebrew.

Needs a notable repository, at least 30 days old: 225 stars, 90 forks or 90 watchers
when its own author submits it (75, 30 or 30 when someone else does). `brew audit --new`
also checks it. And it needs a Developer ID (`setup-developer-id`): Homebrew requires the
app to pass Gatekeeper.

## The terms for AI-written pull requests

Homebrew accepts pull requests written with AI on these terms; tell the user before
starting:

- The pull request says that AI was used, and which tool.
- The user reviews everything before asking maintainers to review it.
- No commit names AI as author or co-author, and no `Assisted-by` or similar trailer.
- The user answers maintainers' questions and review comments themselves.

Forking, pushing and opening the pull request act on the user's GitHub account: ask
before each.

## 1. Write the cask

`brew generate-cask-token "<path to the .app>"` gives the token. Take the values from
`App/Configs/Identity.xcconfig`, `version.txt` and the DMG of the latest published
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

- `desc`: ask the user what the app is, then follow Homebrew's Description Guidelines: a
  neutral one-liner, without the app's name or marketing words.
- `livecheck`: release-please creates the tag while the release is still a draft, so the
  default strategy, which reads tags, can see a version whose DMG cannot be downloaded
  yet. `:github_latest` reads only published releases.

## 2. Check it

In a checkout of `homebrew/cask`, in `Casks/<first letter of token>/`:

```bash
brew tap --force homebrew/cask
cd "$(brew --repository homebrew/cask)"
git checkout -b <token> origin/HEAD
cp <cask file> "Casks/<letter>/<token>.rb"
HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask <token>
brew uninstall --cask <token>
brew audit --new --cask <token>
brew style --fix --cask <token>
brew lgtm --online
```

`brew audit --new` also checks the repository's notability and the download.

## 3. Open the pull request

With the user's go-ahead: fork (`gh repo fork Homebrew/homebrew-cask --clone=false`),
`git remote add <user> https://github.com/<user>/homebrew-cask.git`, commit as
`<token> <version> (new cask)` with no AI trailer, push, and open the pull request: fill
in its template and disclose the AI use. Then the user follows up with the maintainers.

## 4. After the merge, in the project

- `README.md`, in the Install section after the DMG instructions:

  ````markdown
  With [Homebrew](https://brew.sh):

  ```bash
  brew install --cask <token>
  ```
  ````

- `docs/RELEASING.md`: replace the `## Homebrew cask (optional)` section, which only
  points to this skill, with `<skill>/wiring/releasing-official.md`.
- Nothing changes in the release workflow or `App/Configs/Identity.xcconfig`. Commit,
  for example `docs: add the homebrew install`.

## From the own tap

When the app has a Developer ID and the repository is notable, submit it as above. After
the merge:

- In the project, remove the `homebrew` job, `scripts/update-cask.sh`, `HOMEBREW_TAP` and
  `HOMEBREW_UNSIGNED`, and switch `README.md` and `docs/RELEASING.md` to the official
  text from step 4.
- In the tap, delete `Casks/<token>.rb` and add `"<token>": "homebrew/cask"` to its
  `tap_migrations.json`, so `brew install --cask <owner>/<name>/<token>` installs the
  official cask.
- Homebrew does not move copies already installed from the tap; they keep updating
  through Sparkle. Tell users who want Homebrew to track the official cask to run
  `brew uninstall --cask <owner>/<name>/<token> && brew install --cask <token>`.
