#!/usr/bin/env bash
# Builds the debug .app and runs it through LaunchServices so it activates like a
# Finder launch (a bare exec stays behind the terminal). Logger output goes to this
# terminal, or to .build/app/run.log without one. Ctrl-C quits the app. Extra
# arguments go to the app.

source "$(dirname "$0")/common.sh"

app=$(scripts/build-app.sh debug)
if ! output=$(tty); then
    output="$ROOT/.build/app/run.log"
    : >"$output"
    log "no terminal; app output goes to $output"
fi

trap 'pkill -f "$ROOT/$app/Contents/MacOS/$APP_NAME" || true' INT TERM
open -n -W --env OS_ACTIVITY_DT_MODE=YES --stdout "$output" --stderr "$output" "$app" --args "$@"
