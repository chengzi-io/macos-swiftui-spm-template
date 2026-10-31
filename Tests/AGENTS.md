# Tests

Swift Testing unit tests and render tests for the package. Supplements the root
[AGENTS.md](../AGENTS.md).

## Layout

| Path | Tests |
|---|---|
| `Tests/Domains/<Domain>Tests/` | a domain's Core logic, and its Live services that have logic of their own |
| `Tests/Features/<Name>Tests/` | target `<Name>FeatureTests`: the feature's models and render tests |
| `Tests/RenderSupport/` | not tests: `render` draws views to PNG for the render tests |
| `App/UITests/` | XCUITest for a few critical flows only |

- Every test target is listed in the `<App>` scheme's Test action; `make lint` fails on one that is missing.
- Examples below name the Notes demo; once it is replaced, use the first real feature.

## Write

- Use Swift Testing (`@Test`, `#expect`, `try #require`), not XCTest; XCTest is only for `App/UITests/`.
- Test models and services with the mocks from their Core, passed in through `init` (`NotesModel(service: MockNoteService(text: …))`).
- Time comes from an injected `Clock`: no `Date()`, no `Task.sleep`, no waiting on the wall clock.
- A Live service with logic of its own (a missing file read as empty) is tested against the real thing, in a temporary directory or a local stub (`LiveNoteServiceTests`). One that only forwards to a framework needs no such test.
- `swift test` does not compile asset or string catalogs: never assert localized text or images; `make smoke` covers resources in the built `.app`.

## Render tests

- Each screen in the states that tell it apart (empty, filled, error), light and dark, in English (`NotesViewRenderTests`).
- `render` writes `.build/renders/<test file>/<test>.png`. After changing a view, run `make test` and look at its images: nothing compares them.
- An `.alert` or a sheet has no window to draw in, so it never shows in a render.
- CI uploads them as the `renders` artifact: `gh run download <run id> -n renders`.

## Never

| Do not | Because |
|---|---|
| delete or loosen an assertion to make a test pass | the test exists to fail when behavior changes; fix the code or ask the user |
| `Task.sleep` or a polling loop in a test (`make lint` rejects `Task.sleep`) | slow and flaky; await the call, use `confirmation`, or advance a test clock |
| `.disabled` or `withKnownIssue` without a link to an issue | a skipped test is forgotten |

## Flaky tests

Reproduce in a loop, find the cause, then fix it; do not retry or skip:
`for i in {1..20}; do swift test --filter NotesModelTests || break; done`

## UI tests

`make test:ui` takes over the mouse and keyboard: run it only when the user asks. GitHub CI
runs it on every PR. The app launches with `UI_TESTING=1` and uses mocks only.
