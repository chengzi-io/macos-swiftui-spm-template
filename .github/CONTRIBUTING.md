# Contributing

## Setup

```bash
make setup    # checks Xcode and tools, installs git hooks
make ci       # what CI runs; must pass before a PR
```

The pre-commit hook formats staged Swift files with `swift format`. Commands,
layout and how the app is built: [docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md).

## Commit and PR titles

PRs are squash-merged and the PR title becomes the commit on `main`, so the
title must follow Conventional Commits:

`<type>(<scope>): <subject>`

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`,
`ci`, `chore`, `revert`. Subject is lowercase, imperative, no trailing period.

A breaking change is `feat(api)!: drop v1 routes` or a `BREAKING CHANGE:`
footer. CI checks the title; release-please reads the resulting commits to
pick the next version and write `CHANGELOG.md`.
