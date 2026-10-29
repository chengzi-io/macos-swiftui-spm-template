---
name: init-project
description: Turn this template into the user's own macOS app - name, bundle id, identity, README, license, locales, optional removal of the Notes demo - then delete this skill. Use when the user asks to initialize, set up, create or rename the app, or asks for any app work (a feature, an icon, a release) while the app is still named after the template.
---

# Init project

Makes the repository the user's app, once. The deterministic work is in `scripts/`;
this file says when to run which script and what to show the user. The rules live in
the scripts: `check.sh` output is the truth about inputs, `apply.sh --help` about
arguments. The last step deletes this skill.

## When to use

- `version.txt` is `0.0.0` and `APP_NAME` in `App/Configs/Identity.xcconfig` is still
  the template's name, and the user wants app work of any kind: run this first.
- The user wants a different name or bundle id before the first release: copy this
  skill from the template repository and run `apply.sh` again (it refuses after a
  release).

## When not to use

- The user is changing the template itself (its scripts, docs or skills).
- The app has shipped (`version.txt` is not `0.0.0`): a new name or bundle id would
  make a different app to macOS, Sparkle and Homebrew.

## Inputs

Ask for all of them in one message, each with its default filled in. `check.sh`
validates every one; do not pre-judge them yourself.

| Input | Flag | Default |
| --- | --- | --- |
| App name (`APP_NAME`; the .app, executable, package, targets, scheme) | `--name` | none: ask |
| Display name (`APP_DISPLAY_NAME`) | `--display-name` | the app name |
| Bundle id (`BUNDLE_ID`) | `--bundle-id` | `com.<gh login>.<lowercased name>` |
| GitHub repository | `--repo` | the `origin` remote |
| Code owner for `.github/CODEOWNERS` | `--codeowner` | `@<gh login>` |
| Copyright holder (LICENSE, `COPYRIGHT`) | `--copyright` | the repository owner |
| Developer ID team (`TEAM_ID`) | `--team-id` | empty: ad-hoc signing |
| Locales to support (`REQUIRED_LOCALES`) | `--locales` | `en` only |
| Remove the Notes demo? | runs `remove-demo.sh` | no |

For locales, ask which languages the app ships in; `en` is always included, as the
source language. Only the locales listed are required in every string catalog.

## Procedure

Run every script from the repository root, as
`.agents/skills/init-project/scripts/<script>`. If a script fails, stop and show the
user its output; do not work around it by editing files.

1. **Preflight.** `check.sh`. It is read-only: clean tree, Xcode matches
   `.xcode-version`, `gh` signed in, `jq`, `origin`, version `0.0.0`. Fix what it
   reports (or ask the user to), and keep the defaults line it prints.
2. **Ask once.** One message with every input from the table and its default.
3. **Validate.** `check.sh --name <Name> [flags]`. Every problem is listed at once;
   ask the user about the ones that need their answer, then run it again until it
   prints `check: ok`. Keep its `args` line: steps 4 and 5 pass exactly that.
4. **Preview.** `apply.sh --dry-run <args>` (and `remove-demo.sh --dry-run` if the user
   wants the demo gone). Show the user the list of renames and files, and wait for
   their go-ahead.
5. **Apply.** `apply.sh <args>`: renames, Identity, LICENSE, CODEOWNERS, README from
   `wiring/README.md`, `REQUIRED_LOCALES`, `docs/assets/icon.*`. Then
   `remove-demo.sh` if the user asked for it.
6. **Finalize.** `finalize.sh`: removes the template-only blocks, this skill and
   `.claude/skills/init-project`, then fails while `init-project`, `template-only` or
   the template's name is left anywhere. Run the `rg` command it prints last and show
   the user it has no hits.
7. **Verify and commit.** `make setup && make ci` must pass. Show the user
   `git diff HEAD --stat` (renames are staged), then
   `git add -A && git commit -m "chore: initialize <Name> from template"`.
8. **First push, with consent.** Ask before `git push origin main`. Tell the user the
   first Release run shows as skipped until release setup is done. Then walk them
   through what is left, one item at a time:
   - say what the app does: the sentence at the top of `README.md`;
   - the icon: the `app-icon` skill;
   - if the demo stayed: replace Notes with the first real feature;
   - one-time release setup in [docs/RELEASING.md](../../../docs/RELEASING.md)
     (`make github-setup`, the GitHub App, `make sparkle-keys`, optional Developer ID),
     which needs their GitHub and Apple accounts.

Each script skips what is already done, so a run that stopped can run again with the
same arguments. To start over, ask the user first, then
`git reset --hard && git clean -fd` (the tree was clean before step 5).

## Never

- edit by hand a file a script owns (the project, schemes, Identity, Package.swift,
  LICENSE, CODEOWNERS, README) or edit the scripts to get past a check
- roll back (`git reset --hard`, `git clean`) without the user's consent
- set up the GitHub App, secrets or Apple accounts for the user
- push, or create the GitHub repository, without the user's consent
- run this skill on the template repository itself

## Files

| File | Does |
| --- | --- |
| `scripts/check.sh` | preflight and every input rule; read-only |
| `scripts/apply.sh` | the rename and identity; `--dry-run` previews, `--help` lists flags |
| `scripts/remove-demo.sh` | removes the Notes demo; `--dry-run` previews |
| `scripts/finalize.sh` | removes template-only blocks and this skill; checks for leftovers |
| `scripts/lib.sh` | shared inputs, rules and file edits the scripts source |
| `wiring/README.md` | the app's README, for its users |
