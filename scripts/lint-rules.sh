#!/usr/bin/env bash
# Checks what swift format and the compiler cannot: APIs agents reach for out of
# habit, and imports that would break the module layering. Module dependencies
# themselves are enforced by Package.swift; any target can import a system
# framework, hence the import checks here.

source "$(dirname "$0")/common.sh"

# All of App/: an extension's target gets its own folder there.
swift_paths=(App Sources Tests)
# Platform and each domain: Core/ holds protocols, types, logic and mocks, Live/ the live
# implementations.
core_paths=(Sources/*/Core)
live_paths=(Sources/*/Live)
# An import, with any attributes or access level before it (@preconcurrency, public).
import='^([@[:alnum:]_]+[[:space:]]+)*import '
status=0

# check <message> <extended regex> <paths...>: reports every matching line.
check() {
    local message=$1 pattern=$2 path hits paths=()
    shift 2
    for path in "$@"; do
        # A glob left as written matched nothing: no domain has that layer yet.
        [[ $path != *'*'* ]] || continue
        [[ -d $path ]] || die "lint-rules.sh: no directory $path"
        paths+=("$path")
    done
    ((${#paths[@]} > 0)) || return 0
    # /usr/bin/grep: the same BSD grep on every Mac and CI runner.
    if hits=$(/usr/bin/grep -rnE --include='*.swift' "$pattern" "${paths[@]}"); then
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
    "${import}SwiftUI\\b" "${core_paths[@]}" "${live_paths[@]}"
check "Core holds protocols, types, logic and mocks; system frameworks belong in Live" \
    "${import}(AppKit|IOKit|Network|Sparkle)\\b" "${core_paths[@]}"
check "a Live target uses Cores, never another Live: a test could not swap one alone" \
    "${import}[[:alnum:]_]+Live\\b" "${live_paths[@]}"
check "wrap AppKit views in an AppKitBridge target, not in a feature" \
    '\bNS(View|ViewController)Representable\b' Sources/Features Sources/AppRoot

# Xcode's Test action lists test bundles by hand. A package test target the app scheme does
# not list is skipped without a word by ⌘U and xcodebuild test; SwiftPM runs it either way,
# so only this check can say so. A stale entry in the scheme needs no check: xcodebuild
# fails on it by name.
scheme="$XCODE_PROJECT/xcshareddata/xcschemes/$APP_TARGET.xcscheme"
[[ -f $scheme ]] || die "lint-rules.sh: no $scheme"
listed=$(grep -B5 'ReferencedContainer = "container:\.\."' "$scheme" |
    sed -nE 's/.*BlueprintIdentifier = "([^"]+)".*/\1/p' | sort -u)
declared=$(swift package dump-package |
    jq -r '.targets[] | select(.type == "test") | .name' | sort -u)
while read -r target; do
    [[ -n $target ]] || continue
    echo "error: $target is not in the Test action of $scheme, so ⌘U and xcodebuild test skip it silently; copy a TestableReference there and change its three names" >&2
    status=1
done < <(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$listed"))

exit $status
