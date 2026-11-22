---
name: setup-project
description: Turn this template into the user's own macOS app - name, bundle id, category, identity, README, license, locales - then push and protect main, and delete this skill. Use when the user asks to initialize, set up, create or rename the app, or asks for any app work while the app is still named after the template.
---

# Set up the project

Makes the repository the user's app, once. `scripts/init.sh` does the deterministic work;
this file says when to run it and what to show the user. The last step deletes this skill.

## When to use

- The `make status` project line says `todo`: the app is still the template's, and the user
  wants app work of any kind (a feature, an icon, a release): run this first.
- The user wants a different name or bundle id before the first release: copy this skill
  from the template repository and run it again (it refuses after a release).

## When not to use

- The user is changing the template itself (its scripts, docs or skills).
- The app has shipped (a `vX.Y.Z` tag exists): a new name or bundle id would make a
  different app to macOS, Sparkle and Homebrew.

## Before you start

Run `init.sh` with no arguments, from the repository root:

    .agents/skills/setup-project/scripts/init.sh

It is read-only. It checks the tools and the repository (Xcode matches `.xcode-version`,
`gh` signed in unless `--codeowner` is given, `origin`, no `vX.Y.Z` tag, a clean tree) and
prints every default it can work out, one per line. Fix what it reports, or ask the user to, and keep that list.

## Ask once

One message, in two parts:

1. The two values marked `(permanent after the first release)`: the app's name (`name`)
   and its bundle id (`bundle-id`, by default `io.github.<repository owner>.<name>`).
   Show each default, or `(ask)`, and get an answer for each, even if it is "keep it":
   a default is never a confirmation. A new name changes the default bundle id with it,
   so confirm that one again.
2. The defaults the user can change at any time: `category`, `repo`, `codeowner`,
   `locales`. `en` is always a required language, as the source language; only the listed
   ones are required in every string catalog. Two values are derived and not asked: the
   display name follows `name`, and the LICENSE holder is the repository owner. `TEAM_ID`
   keeps its current value.

## Plan

    .agents/skills/setup-project/scripts/init.sh --dry-run --name <Name> [options]

Every input is validated and every problem listed at once. Then it prints each change as a
`would …` line. Show the user that list and wait for their go-ahead. It changes nothing.

## Apply

    .agents/skills/setup-project/scripts/init.sh --name <Name> [options]

The same checks, then the changes, then what is left to do. If it fails, stop and show the
user its output; do not work around it by editing files. Each step skips what is already
done, so a run that stopped can run again with the same arguments.

## Verify and commit

`make setup && make ci` must pass. Show the user `git diff HEAD --stat` (the
deletions are staged), then

    git add -A && git commit -m "chore: initialize <Name> from template"

## Push and protect, with consent

Ask before `git push origin main`. Then ask before `make github-settings`, and say what it
changes: from then on `main` only takes pull requests, admins included. It needs `gh`
signed in with admin rights on the repository.

## Next

Tell the user to run `make status` whenever they want to go on: the first `todo` line is
the next step, and the last line says how to start it.

## Changes

- `App/Configs/Identity.xcconfig`: `APP_NAME`, `APP_DISPLAY_NAME`, `BUNDLE_ID`,
  `APP_CATEGORY`, `GITHUB_REPOSITORY`;
- `App/Configs/Info.plist`: `CFBundleLocalizations`, the app's languages;
- `LICENSE`, `.github/CODEOWNERS`, `.github/ISSUE_TEMPLATE/config.yml`;
- `README.md`, from `wiring/README.md`: the app's page, with its Install and Update
  sections;
- this skill and `.claude/skills/setup-project`.

## Never

- edit by hand a file the script owns (the project, schemes, Identity, Package.swift,
  LICENSE, CODEOWNERS, README) or edit the script to get past a check
- roll back (`git reset --hard`, `git clean`) without the user's consent
- set up the secrets or Apple accounts for the user
- push, or create the GitHub repository, without the user's consent
- run this skill on the template repository itself

## Files

| File | Does |
| --- | --- |
| `scripts/init.sh` | the preflight, the input rules, the plan and the changes; `--help` lists the modes and options |
| `wiring/README.md` | the app's README, for its users |
