# Contributing

How commits, PRs and docs are written here.

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
- The type decides what ships ([docs/RELEASING.md](../docs/RELEASING.md#versions)):
  `feat`, `fix`, `perf`, `revert` and breaking changes do; a `refactor` only appears in
  the next release's notes; the rest stays out. A change users can see is a `feat` or a
  `fix`, even when it came out of a restructuring.

## PR flow

1. Branch from `main`; one PR does one thing.
2. `make ci` green locally, then push and open the PR; CI also runs the UI tests,
   shellcheck and actionlint.
3. The PR is squash-merged once CI is green.

`make github-settings` enforces this flow on GitHub, admins included: a direct push to
`main` is rejected. Run it after the first push, and again when a second person can push.

The checks stop mistakes, not someone set on getting past them. With two or more pushers,
`main` also needs an approving review, and nobody approves their own PR. A token that can
push can merge, so give an agent no write access, or a GitHub account of its own.

The template ships no `.github/CODEOWNERS`. Add one (`* @owner`) when someone should be
requested on every PR: the review rule above comes from branch protection, not from that
file.

A merge to `main` ships nothing by itself: run the Release workflow when you want a
version out, and publish the draft it leaves ([docs/RELEASING.md](../docs/RELEASING.md)).

## Docs style

1. The first line says what the file is for and who reads it; a file that outgrows one reader splits.
2. Tables for mappings and options, numbered lists for steps; no paragraph over 4 lines.
3. Each fact lives in one place; elsewhere, link to it. Commands go in code blocks.
4. Rules read "Do X" or "Don't Y, because Z", with a one-sentence reason.
5. Agent files (`AGENTS.md`) hold no background for people; people's docs hold no agent orders.
6. Shipped docs are in English, with a Chinese copy beside them (`README.zh-CN.md`, `docs/zh/`).
   English is the source: a change lands there first, then in the copy. `make lint` checks
   links and `AGENTS.md`/`CLAUDE.md` pairs.
