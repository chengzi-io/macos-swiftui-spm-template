#!/usr/bin/env bash
# Checks what swift format and the compiler cannot: APIs agents reach for out of
# habit, imports and target dependencies that would break the module layering, the
# files that have to agree with Package.swift or with each other, and the docs' budgets
# and links. Package.swift only makes a target declare what it imports, and any target
# can import a system framework.

source "$(dirname "$0")/common.sh"

# All of App/: an extension's target gets its own folder there.
swift_paths=(App Sources Tests)
# Platform and each domain: Core/ holds protocols, types, logic and mocks, Live/ the live
# implementations.
core_paths=(Sources/*/Core)
live_paths=(Sources/*/Live)
# Everything but Live/: the code that takes the time from an injected Clock.
non_live_paths=(App Tests Sources/AppRoot Sources/Features "${core_paths[@]}")
test_paths=(Tests App/UITests)
# An import, with any attributes or access level before it (@preconcurrency, public), and
# the kind of a single-symbol import (import struct SwiftUI.Color).
import='^(?:[@\w]+[ \t]+)*import[ \t]+(?:(?:typealias|struct|class|enum|protocol|let|var|func)[ \t]+)?'
status=0

# check <message> <perl regex> <paths...>: reports every match in the .swift files under
# paths. Lines that start with // are blanked first, so a comment that names an API is not
# a use of it. The regex sees the whole file (^ is a line start, \s matches a line break
# too), so a call written over several lines still matches; a hit shows its first line.
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
    hits=$(find "${paths[@]}" -name '*.swift' -type f | sort | tr '\n' '\0' | xargs -0 perl -e '
        my $pattern = shift;
        for my $file (@ARGV) {
            open my $fh, "<", $file or die "$file: $!\n";
            my @lines = <$fh>;
            close $fh;
            my $code = join "", map { m{^\s*//} ? "\n" : $_ } @lines;
            while ($code =~ /$pattern/mg) {
                my $line = 1 + (substr($code, 0, $-[0]) =~ tr/\n//);
                print "$file:$line:$lines[$line - 1]";
            }
        }' "$pattern")
    if [[ -n $hits ]]; then
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
    "${import}(?:AppKit|IOKit|Network|Sparkle)\\b" "${core_paths[@]}"
check "fix the isolation instead of silencing the compiler: an actor, a Sendable value, or state behind OSAllocatedUnfairLock" \
    '@unchecked\s+Sendable\b|nonisolated\(unsafe\)' "${swift_paths[@]}"
check "pass models through initializers, not the environment: a missing argument fails the build, a missing environment object crashes at run time" \
    '\.environment\(\s*[A-Za-z_]|@Environment\([A-Z]\w*\.self\)' "${swift_paths[@]}"
check "pass a service in through an initializer, not a static shared instance: a test cannot swap a singleton" \
    '\bstatic\s+(?:let|var)\s+shared\b' "${swift_paths[@]}"
check "take the time from an injected Clock; only Live reads the system clock" \
    '\bDate\(\)|\bDate\.now\b' "${non_live_paths[@]}"
check "wait on what the test checks (await, confirmation, a mock clock), not Task.sleep: a sleep is slow and flaky" \
    '\bTask\.sleep\b' "${test_paths[@]}"
check "log with the module's Logger (Log.swift), not print: print reaches no log and ships in release builds" \
    '(?<![.\w])(?:print|debugPrint)\(' "${swift_paths[@]}"
check "handle or throw the error instead of try!; in a test, use try #require or let the test throw" \
    '\btry!' "${swift_paths[@]}"

package=$(swift package dump-package)

# Which targets may depend on which (AGENTS.md). Test targets depend on what they test.
while read -r target dependency; do
    case $dependency in
        *Live)
            echo "error: $target depends on $dependency; only the app target builds Live services (App/Application/MainApp.swift) and hands them over as their Core protocols" >&2
            status=1
            ;;
        *Feature)
            [[ $target == AppRoot ]] && continue
            echo "error: $target depends on $dependency; a feature never depends on another, and only AppRoot puts them together" >&2
            status=1
            ;;
    esac
done < <(jq -r '.targets[] | select(.type == "regular") | .name as $target
    | .dependencies[] | (.byName // .target // empty)[0] | "\($target) \(.)"' <<<"$package")

# Xcode's Test action lists test bundles by hand. A package test target the app scheme does
# not list is skipped without a word by ⌘U and xcodebuild test; SwiftPM runs it either way,
# so only this check can say so. A stale entry in the scheme needs no check: xcodebuild
# fails on it by name.
scheme="$XCODE_PROJECT/xcshareddata/xcschemes/$APP_TARGET.xcscheme"
[[ -f $scheme ]] || die "lint-rules.sh: no $scheme"
listed=$(grep -B5 'ReferencedContainer = "container:\.\."' "$scheme" |
    sed -nE 's/.*BlueprintIdentifier = "([^"]+)".*/\1/p' | sort -u)
declared=$(jq -r '.targets[] | select(.type == "test") | .name' <<<"$package" | sort -u)
while read -r target; do
    [[ -n $target ]] || continue
    echo "error: $target is not in the Test action of $scheme, so ⌘U and xcodebuild test skip it silently; copy a TestableReference there and change its three names" >&2
    status=1
done < <(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$listed"))

# Every string in each locale of REQUIRED_LOCALES (App/Configs/Identity.xcconfig, space
# separated; en when unset). A catalog's key is its source-language text, so the source
# language needs no entry; a plural lists one state per form.
for locale in ${REQUIRED_LOCALES:-en}; do
    while read -r catalog; do
        [[ $locale != "$(jq -r '.sourceLanguage' "$catalog")" ]] || continue
        while read -r key; do
            [[ -n $key ]] || continue
            echo "error: $catalog: \"$key\" has no $locale translation; add one, or take $locale out of REQUIRED_LOCALES in App/Configs/Identity.xcconfig" >&2
            status=1
        done < <(jq -r --arg locale "$locale" '.strings | to_entries[] | select(.value.shouldTranslate != false)
            | select([.value.localizations[$locale] // {} | .. | objects | .stringUnit? // empty | .state]
                | length == 0 or any(. != "translated"))
            | .key' "$catalog")
    done < <(find Sources App -name '*.xcstrings' | sort)
done

# Xcode resolves the app's packages into its own Package.resolved; swift test and
# dependabot write only the root one, so the app could ship other versions than the tests
# ran against.
xcode_resolved="$XCODE_PROJECT/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
pins() {
    jq -S '.pins | sort_by(.identity)' "$1"
}
if ! diff -u <(pins Package.resolved) <(pins "$xcode_resolved") >&2; then
    echo "error: Package.resolved and $xcode_resolved pin different versions; swift test and dependabot write the first, Xcode the second: copy the one with the versions you want over the other, then make test app" >&2
    status=1
fi

# The package and the Xcode project build for the same macOS: with a lower package platform
# swift test accepts an API the app target rejects, with a higher one the reverse.
major_minor() {
    sed -E 's/^([0-9]+)$/\1.0/; s/^([0-9]+\.[0-9]+)\..*/\1/' <<<"$1"
}
package_macos=$(jq -r '.platforms[]? | select(.platformName == "macos") | .version' <<<"$package")
if [[ -z $package_macos ]]; then
    echo "error: Package.swift lists no .macOS platform" >&2
    status=1
fi
grep -q '^MACOSX_DEPLOYMENT_TARGET' App/Configs/Project.xcconfig || {
    echo "error: App/Configs/Project.xcconfig sets no MACOSX_DEPLOYMENT_TARGET" >&2
    status=1
}
while IFS=: read -r xcconfig value; do
    if [[ $(major_minor "$value") != "$(major_minor "$package_macos")" ]]; then
        echo "error: $xcconfig sets MACOSX_DEPLOYMENT_TARGET = $value, Package.swift .macOS $package_macos; change them together" >&2
        status=1
    fi
done < <(find App -name '*.xcconfig' | sort | while read -r xcconfig; do
    sed -nE "s|^MACOSX_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*([^[:space:]]+).*|$xcconfig:\\1|p" "$xcconfig"
done)

# Build settings live in App/Configs/*.xcconfig. Xcode writes one into project.pbxproj when
# it is set in the Build Settings or Signing panel, and there it wins over the xcconfig.
hits=$(awk '/buildSettings = \{/ { inside = 1; next }
    inside && /^[[:space:]]*\};/ { inside = 0; next }
    inside { print FILENAME ":" FNR ":" $0 }' "$XCODE_PROJECT/project.pbxproj")
if [[ -n $hits ]]; then
    echo "$hits" >&2
    echo "error: $XCODE_PROJECT/project.pbxproj has build settings; move them to App/Configs/*.xcconfig and leave its buildSettings blocks empty" >&2
    status=1
fi

# Docs stay inside their line budgets, link only to files that exist and name only make
# targets that make help lists. Tracked and new files alike, ignored ones (.build/) not.
docs=$(git ls-files --cached --others --exclude-standard -- '*.md' | sort -u)

# <path> <max lines>; a file that does not exist yet is skipped. A file joins this list in
# the change that cuts it to its budget: AGENTS.md 100, README.md 60, docs/ARCHITECTURE.md
# 150, docs/DEVELOPMENT.md 80, docs/RELEASING.md 100, .agents/skills/*/SKILL.md 150.
while read -r doc budget; do
    [[ -f $doc ]] || continue
    lines=$(wc -l <"$doc" | tr -d ' ')
    if ((lines > budget)); then
        echo "error: $doc has $lines lines, over its budget of $budget; split it or move the detail into a linked file" >&2
        status=1
    fi
done <<'BUDGETS'
.agents/skills/add-feature/SKILL.md 150
Sources/AGENTS.md 80
Tests/AGENTS.md 50
App/AGENTS.md 40
scripts/AGENTS.md 30
.github/AGENTS.md 30
docs/TOOLCHAIN.md 60
.github/CONTRIBUTING.md 50
BUDGETS

# Every AGENTS.md has a CLAUDE.md beside it that only loads it.
while read -r doc; do
    [[ $(basename "$doc") == AGENTS.md ]] || continue
    claude="$(dirname "$doc")/CLAUDE.md"
    if [[ ! -f $claude || $(cat "$claude") != "@AGENTS.md" ]]; then
        echo "error: $doc needs a $claude beside it holding only the line @AGENTS.md" >&2
        status=1
    fi
done <<<"$docs"

# Relative links resolve; the #fragment is not checked. A skill copies its wiring/ files
# elsewhere, so their links point from where they land.
while read -r doc; do
    [[ -n $doc && $doc != .agents/skills/*/wiring/* ]] || continue
    while IFS=: read -r line target; do
        target=${target%%#*}
        [[ -n $target ]] || continue
        if [[ ! -e "$(dirname "$doc")/$target" ]]; then
            echo "error: $doc:$line links to $target, which does not exist" >&2
            status=1
        fi
    done < <(perl -ne 'while (/\]\(([^)\s]+)/g) { my $t = $1; print "$.:$t\n" unless $t =~ m{^(?:[a-z]+:|#|<)} }' "$doc")
done <<<"$docs"

# A make target named in the docs is one make help lists: `make x` in text, or a line of a
# ``` block starting with make. Skills are left out: their wiring adds targets (make release-mas)
# to the Makefile it is copied into.
targets=$(make --no-print-directory -s help | awk '/^  [a-z]/ { print $1 }')
while read -r doc; do
    [[ -n $doc && $doc != .agents/* ]] || continue
    while IFS=: read -r line target; do
        if ! grep -qxF -- "$target" <<<"$targets"; then
            echo "error: $doc:$line names make $target, which make help does not list" >&2
            status=1
        fi
    done < <(perl -ne '$fence = !$fence if /^\s*```/;
        my $start = $fence ? qr/^\s*(?:\$\s+)?|`/ : qr/`/;
        while (/(?:$start)make\s+([a-z][a-z:-]*[a-z])/g) { print "$.:$1\n" }' "$doc")
done <<<"$docs"

exit $status
