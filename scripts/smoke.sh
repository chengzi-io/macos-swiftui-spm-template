#!/usr/bin/env bash
# Smoke-tests a built .app (default: the debug build): signature, Info.plist,
# resource bundle, compiled assets, then launches it and checks it is still alive
# after startup.
# A missing resource bundle crashes the first render through Bundle.module.

source "$(dirname "$0")/common.sh"

app=${1:-$DEBUG_APP}
[[ -d $app ]] || die "no app at $app; run make app first"

codesign --verify --deep --strict "$app"
plutil -lint -s "$app/Contents/Info.plist"
[[ -d "$app/Contents/Resources/App_AppCore.bundle" ]] || die "$app has no App_AppCore.bundle"
# A missing icon or accent color fails nothing at runtime.
for asset in Assets.car AppIcon.icns; do
    [[ -f "$app/Contents/Resources/$asset" ]] || die "$app has no $asset"
done

output=$(mktemp)
trap 'rm -f "$output"' EXIT
"$app/Contents/MacOS/$APP_NAME" >"$output" 2>&1 &
pid=$!
sleep 5
if ! kill -0 "$pid" 2>/dev/null; then
    cat "$output" >&2
    die "$app exited during startup"
fi
kill "$pid"
wait "$pid" 2>/dev/null || true
log "smoke ok: $app"
