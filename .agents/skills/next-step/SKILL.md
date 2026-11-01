---
name: next-step
description: Say where this project stands and what comes next, then do that step with the user's consent - runs make status, explains the next step (what it changes, the user's part, whether it can be undone) and starts the matching skill. Use when the user says "next step", asks what to do next, or asks where the project stands.
---

# Next step

Tells the user where the project stands and runs what comes next, one step at a time.

## Status

Moves no line itself: it reads `make status` and starts the skill that moves the next one.

## Steps

### 1. Read where the project stands

Run `make status`. Each line is one step of the route below, in order: `ok` done, `todo`
still to do, `--` optional and not started, `?` unknown, with the reason. The `next:` line
names the first `todo`.

### 2. Tell the user

In plain words, short:

- where the project is: the `ok` steps, in one sentence;
- the next step, from the table below: what it changes, what the user does themselves,
  and whether it can be undone;
- the optional steps (`--`) only when nothing is `todo`, or when the user asks;
- a `?` line: its reason, and how to fix it.

### 3. Wait for the go-ahead, then run it

Start the skill the `next:` line names, or the one the user picks instead. That skill
asks its own questions and shows its own plan. Never run two steps in one go.

### 4. Report

Run `make status` again. Say what changed and what comes next.

## The route

<!-- template-only:start -->
While the `project` line is `todo`, the next step is the `setup-project` skill: it sets the
name, bundle id, identity, README and license. The user confirms the name and the bundle
id; both are permanent after the first release.
<!-- template-only:end -->

| Line | Run | What changes | The user's part | Undo |
| --- | --- | --- | --- | --- |
| `setup` | `make setup` | git hooks on this Mac | none | `lefthook uninstall` |
| `repo` | `git push origin main`, then `make github-settings` | GitHub settings: `main` only takes pull requests, admins included | consent; `gh` signed in as an admin | on GitHub, any time |
| `icon` | the `design-app-icon` skill | `App/Application/AppIcon.icon` | pick or approve a concept | yes |
| `demo` | the `add-feature` skill | the first feature replaces the Notes demo | say what the feature does | yes, by git |
| `dmg` | the `design-dmg-window` skill | `App/Configs/DMG` | approve the window | yes |
| `releases` | the `setup-releases` skill | the release pipeline, the GitHub App, the Sparkle key | two clicks in the browser; export and back up the key | the Sparkle key never: without it, installed copies cannot update |
| `signing` | the `setup-developer-id` skill | `TEAM_ID` and five secrets | an Apple Developer account; the certificate and key | yes |
| `homebrew` | the `setup-homebrew` skill | a cask, in the user's tap or `homebrew/cask` | a tap repository, or Homebrew's review | yes |

New features, capabilities (`add-capability`) and design changes come any time after the
`project` line is `ok`; they are not steps of the route.

## Never

- run a step, or `make github-settings`, without the user's go-ahead
- change a file yourself: the skills make the changes; the one command run directly is
  `make github-settings`
- skip a `todo` to run a later step, unless the user asks for that step
