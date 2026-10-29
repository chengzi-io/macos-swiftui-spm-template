# Contributing

How commits, PRs and docs are written here. For people and agents.

## Setup

```bash
make setup    # checks Xcode and tools, installs git hooks
make ci       # what CI runs; must pass before a PR
```

The pre-commit hook formats staged Swift files with `swift format`. The daily loop:
[docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md); versions: [docs/TOOLCHAIN.md](../docs/TOOLCHAIN.md).

## Commit and PR titles

PRs are squash-merged and the PR title becomes the commit on `main`, so the title
follows Conventional Commits (CI checks it): `<type>(<scope>): <subject>`.

- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`,
  `chore`, `revert`. The subject is lowercase, imperative, with no trailing period.
- A breaking change is `feat(api)!: drop v1 routes` or a `BREAKING CHANGE:` footer.

## PR flow

1. Branch from `main`; one PR does one thing.
2. `make ci` green locally, then push and open the PR; CI also runs the UI tests,
   shellcheck and actionlint.
3. The PR is squash-merged once CI is green.

release-please turns `feat` and `fix` commits into a release PR; merging it tags
`vX.Y.Z`, and the release workflow attaches the DMG, dSYM and appcast:
[docs/RELEASING.md](../docs/RELEASING.md).

## Docs style

1. The first line says what the file is for and who reads it; past its line budget, split it.
2. Tables for mappings and options, numbered lists for steps; no paragraph over 4 lines.
3. Each fact lives in one place; elsewhere, link to it. Commands go in code blocks.
4. Rules read "Do X" or "Don't Y, because Z", with a one-sentence reason.
5. Agent files (`AGENTS.md`) hold no background for people; people's docs hold no agent orders.
6. Shipped docs are in English. `make lint` checks budgets, links and `AGENTS.md`/`CLAUDE.md` pairs.
