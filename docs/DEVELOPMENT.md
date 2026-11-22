# Development

The daily loop, editors and commands, for people working on the app. Toolchain:
Xcode 26.2, the version CI uses ([TOOLCHAIN.md](TOOLCHAIN.md)); `make doctor` checks it.

## Daily loop

```mermaid
flowchart LR
    setup["make setup<br/>once per clone"] --> edit["edit"]
    edit --> test["make test<br/>seconds"]
    test -->|fails| edit
    test --> look["look at the renders<br/>of changed views"]
    look --> ci["make ci<br/>before a PR"]
    ci --> pr["PR: Conventional<br/>Commit title"]
```

1. `make setup` once: checks the toolchain and installs the git hooks.
2. `make test` after every change. Its render tests draw each screen, light and dark,
   to `.build/renders/<test file>/<test>.png`. Nothing compares them: open the images
   of the views you changed.
3. `make ci` before you open a PR. It is the definition of done.
4. Open the PR with a Conventional Commit title
   ([CONTRIBUTING](../.github/CONTRIBUTING.md)); it is squash-merged. Shipping a version:
   [RELEASING.md](RELEASING.md).

CI uploads the renders it draws on macOS 26 as the run's `renders` artifact:
`gh run download <run id> -n renders`.

## Commands

`make help` lists the entry points; these are the ones you use daily. `make build`, `make
smoke` and `make lint-assets` are steps of `make ci`, so `make help` leaves them out;
they run on their own too.

| Command | Does | When |
| --- | --- | --- |
| `make setup` | `make doctor`, then installs the git hooks | once per clone |
| `make doctor` | checks Xcode, tools and the signing identity | when a build fails oddly |
| `make status` | where the project stands, from template to release, and what comes next | any time |
| `make github-settings` | squash merge, `main` protected, Dependabot and secret scanning on GitHub | after the first push; when a second person can push |
| `make test` | package unit tests and renders, no app | after every change |
| `make run` | builds and launches the debug app, logs in the terminal | to try a change |
| `make fmt` | formats Swift sources in place | before committing |
| `make lint` | formatting and `scripts/dev/lint-rules.sh` | part of `make ci` |
| `make lint-assets` | compiles the asset catalog and `AppIcon.icon` with actool, fails on any warning | after an icon change; part of `make ci` |
| `make build` | builds the debug .app, ad-hoc signed | to check the app target builds |
| `make ci` | lint, test, lint-assets, build, smoke | before a PR |
| `make test-ui` | XCUITests; they take over the mouse and keyboard | when asked; CI runs them on every PR |
| `make clean` | removes build output | after a toolchain change |

| Task | Command |
| --- | --- |
| Run in Chinese | `make run ARGS="-AppleLanguages '(zh-Hans)'"` |
| UI tests without a password prompt | `sudo automationmodetool enable-automationmode-without-authentication`, once |

## Editors

| Editor | Setup | Notes |
| --- | --- | --- |
| Xcode | `xed App/App.xcodeproj` | Run builds the real `.app` with the debugger attached; previews run in the package targets |
| Xcode, package only | `xed .` | the package without the app shell |
| VS Code, Cursor, Zed | the Swift extension (sourcekit-lsp) | loads the package at the root; `App/` gets no code intelligence, so use `make run` |

`<App>` is the app's name, `APP_NAME` in `App/Configs/Identity.xcconfig`
([App/AGENTS.md](../App/AGENTS.md) says who sets each identity key).

## Where code goes

Where a file belongs and which way dependencies point: [Sources/AGENTS.md](../Sources/AGENTS.md);
why: [ARCHITECTURE.md](ARCHITECTURE.md). To add a feature, run `make feature
NAME=<Area>`: it writes the feature, its tests and the targets, then prints the two lines
that wire it.
