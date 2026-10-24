#!/usr/bin/env bash
# Checks what swift format and the compiler cannot: APIs agents reach for out of
# habit, and imports that would break the module layering. Module dependencies
# themselves are enforced by Package.swift; any target can import a system
# framework, hence the import checks here.

source "$(dirname "$0")/common.sh"

swift_paths=(App/Application App/UITests Sources Tests)
# Platform and each domain: Core/ holds protocols, types, logic and mocks, Live/ the live
# implementations.
core_paths=(Sources/*/Core)
live_paths=(Sources/*/Live)
status=0

# check <message> <extended regex> <paths...>: reports every matching line.
check() {
    local message=$1 pattern=$2 path hits
    shift 2
    for path in "$@"; do
        [[ -d $path ]] || die "lint-rules.sh: no directory $path"
    done
    # /usr/bin/grep: the same BSD grep on every Mac and CI runner.
    if hits=$(/usr/bin/grep -rnE --include='*.swift' "$pattern" "$@"); then
        echo "$hits" >&2
        echo "error: $message" >&2
        status=1
    fi
}

check "use an @Observable model, not ObservableObject or @Published" \
    '\bObservableObject\b|@Published\b' "${swift_paths[@]}"
check "use NavigationStack or NavigationSplitView, not NavigationView" \
    '\bNavigationView\b' "${swift_paths[@]}"
check "use foregroundStyle(_:), not foregroundColor(_:)" \
    '\.foregroundColor\(' "${swift_paths[@]}"
check "Core and Live hold no views; UI belongs in a feature" \
    '^import SwiftUI\b' "${core_paths[@]}" "${live_paths[@]}"
check "Core holds protocols, types, logic and mocks; system frameworks belong in Live" \
    '^import (AppKit|IOKit|Network|Sparkle)\b' "${core_paths[@]}"
check "wrap AppKit views in an AppKitBridge target, not in a feature" \
    '\bNS(View|ViewController)Representable\b' Sources/Features Sources/AppRoot

exit $status
