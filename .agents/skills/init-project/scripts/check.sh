#!/usr/bin/env bash
# Read-only: checks the tools and the repository, then, given --name, every input init
# takes. Prints every problem at once; exits 1 when there is any. Changes no file.
#
#   check.sh                         preflight only; prints the defaults it can work out
#   check.sh --name MyApp [options]  preflight and all inputs; prints the resolved inputs
#
# Options (all but --name default as printed): --display-name "My App"
#   --bundle-id com.example.myapp --repo owner/repo --codeowner @user-or-@org/team
#   --copyright "Jane Doe" --team-id ABCDE12345 --locales "en zh-Hans"
#   --skip-xcode   skip the Xcode check (only to test the scripts on a machine without Xcode)

source "$(dirname "$0")/lib.sh"

usage() {
    sed -n '2,12p' "$0" | sed -E 's/^# ?//' >&2
    exit "$1"
}

parse_inputs "$@"
((dry_run == 0)) || usage 1
preflight
resolve_defaults
if [[ -z $name ]]; then
    echo "defaults: repo ${repo:-?}, codeowner ${codeowner:-?}, copyright holder ${holder:-?}, bundle id com.$(printf %s "${gh_login:-you}" | tr "[:upper:]" "[:lower:]").<name>, locales en"
else
    validate
fi
if ((errors > 0)); then
    echo "check: $errors problem(s); nothing was changed" >&2
    exit 1
fi
[[ -z $name ]] || print_inputs
echo "check: ok" >&2
