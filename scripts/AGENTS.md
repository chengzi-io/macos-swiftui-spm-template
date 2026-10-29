# scripts

Conventions for the bash scripts behind the Makefile, CI and releases. Supplements the root
[AGENTS.md](../AGENTS.md).

## Write

- Start with `#!/usr/bin/env bash`, then a comment saying what the script does, its arguments and its output; then `source "$(dirname "$0")/common.sh"`.
- `common.sh` sets `set -euo pipefail`, runs from the repository root, exports the keys of `App/Configs/Identity.xcconfig` and defines `die`, `log` and the shared paths: use them, do not redefine them.
- Write for macOS's bash 3.2: no associative arrays, no `mapfile`, guard empty arrays.
- Write for BSD tools, not GNU: `sed -i ''`, `/usr/bin/grep` without `-P` (use `perl` for PCRE).
- Errors go through `die "<what failed>; <how to fix it>"` to stderr; progress through `log`; stdout carries only the result a caller reads.
- Quote every expansion; pass lists as arrays (`"${args[@]}"`), not strings.
- A script a person runs gets a Makefile target with a `##` help line in its section.

## Check

- CI runs `shellcheck --external-sources --source-path=SCRIPTDIR --severity=warning` on every `*.sh` and `actionlint` on the workflows (`.github/workflows/ci.yml`).
- Run the same shellcheck locally before pushing a script change. Disable a finding only on its line, with a `# shellcheck disable=SCxxxx # reason` comment.
- A check in `lint-rules.sh` prints `error: <what>; <fix>` and sets `status=1` rather than exiting, so one run reports every finding.

## Never

| Do not | Because |
|---|---|
| depend on Homebrew GNU tools (`gsed`, `ggrep`, `gdate`) | a fresh Mac and the CI runner have only the BSD ones |
| read a secret from a file in the repository or print it | secrets arrive as environment variables from CI or the keychain |
