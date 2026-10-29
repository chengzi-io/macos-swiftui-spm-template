# .github

Rules for the workflows, templates and repository settings files. Supplements the root
[AGENTS.md](../AGENTS.md); contributor guide: [CONTRIBUTING.md](CONTRIBUTING.md).

| File | Runs |
|---|---|
| `workflows/ci.yml` | every PR: `make ci` and `make test:ui` on `macos-26`; shellcheck and actionlint on Linux |
| `workflows/pr-title.yml` | every PR: the title follows Conventional Commits, since it becomes the squash commit |
| `workflows/release.yml` | every push to `main`: release-please, then `make release` and the upload when a tag is cut |
| `dependabot.yml` | security updates for Swift packages; weekly bumps of the pinned actions |

## Rules

- Pin every action to a full commit SHA with its version in a comment (`uses: owner/action@<sha> # v1.2.3`); dependabot bumps both.
- Select Xcode from `.xcode-version`, the only place its version is written; never hard-code it in a workflow.
- Run the Mac jobs on `macos-26`: GitHub's `macos-15` image (15.7.9) crashes in Xcode 26 compiling `AppIcon.icon`.
- Keep `run:` steps short: logic belongs in a `make` target or a script in `scripts/`, which runs locally too.
- Give each workflow `permissions: contents: read` and raise it only in the job that needs more.
- Pass secrets to a step through `env:`, never inline in `run:`; `release.yml` only reaches them through the `release` environment.
- Run `actionlint` after editing a workflow; CI runs version 1.7.12.

## Never

| Do not | Because |
|---|---|
| edit repository settings, secrets or branch protection from an agent | they are the user's; ask them |
| check out or run PR code in a `pull_request_target` workflow (`pr-title.yml` reads only the title) | it runs with the base repository's token and secrets |
