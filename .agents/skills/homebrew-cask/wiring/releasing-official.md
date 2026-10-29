## Homebrew cask

The app is in the official `homebrew/cask`; users install it with
`brew install --cask <token>`. Homebrew's BrewTestBot checks the latest published GitHub
release every 3 hours (the cask's `livecheck` uses `:github_latest`, so draft releases
stay invisible to it) and opens the update pull request itself. The release workflow
does nothing for Homebrew.

The cask keeps working while releases stay as they are: Developer ID signed and
notarized, `<App>-X.Y.Z.dmg` under the `vX.Y.Z` release. A change beyond the version (the
DMG's name, the tag format, the minimum macOS) needs a pull request to
`Homebrew/homebrew-cask`, under the same rules as the first one: say that AI was used,
review it yourself, no AI trailer on the commit, and answer the maintainers yourself.
