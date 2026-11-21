#!/usr/bin/env bash
# Runs swift format lint, then checks what swift format and the compiler cannot: APIs
# agents reach for out of habit, imports and target dependencies that would break the
# module layering, the files that have to agree with Package.swift or with each other, the
# docs' links, and the rule that nothing here reads a skill. Package.swift only makes a
# target declare what it imports, and any target can import a system framework.

source "$(dirname "$0")/../common.sh"

# The manifest itself says where every target lives, so the checks below read it instead
# of guessing from directory shapes.
package=$(swift package dump-package)
# Domains under Sources/Domains/: the <Name> target holds protocols, types, logic and
# mocks, <Name>Live the live implementations. The target's name picks its side, so a
# renamed or misplaced folder cannot dodge a rule.
core_paths=()
live_paths=()
while read -r name path; do
    case $name in
    *Live) live_paths+=("$path") ;;
    *) core_paths+=("$path") ;;
    esac
done < <(jq -r '.targets[]
    | select(.type == "regular" and ((.path // "") | startswith("Sources/Domains/")))
    | "\(.name) \(.path)"' <<<"$package")
# Everything but the Live targets: the code that takes the time from an injected Clock.
non_live_paths=(App Tests Sources/AppRoot Sources/Features ${core_paths[@]+"${core_paths[@]}"})
test_paths=(Tests App/UITests)
# An import, with any attributes or access level before it (@preconcurrency, public), and
# the kind of a single-symbol import (import struct SwiftUI.Color).
import='^(?:[@\w]+[ \t]+)*import[ \t]+(?:(?:typealias|struct|class|enum|protocol|let|var|func)[ \t]+)?'
status=0

swift format lint --strict --recursive --parallel "${SWIFT_PATHS[@]}" || status=1

# check <message> <perl regex> <paths...>: reports every match in the .swift files under
# paths. Lines that start with // are blanked first, so a comment that names an API is not
# a use of it. The regex sees the whole file (^ is a line start, \s matches a line break
# too), so a call written over several lines still matches; a hit shows its first line.
check() {
    local message=$1 pattern=$2 path hits paths=()
    shift 2
    for path in "$@"; do
        [[ -e $path ]] || die "lint-rules.sh: no $path"
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
    '\bObservableObject\b|@Published\b' "${SWIFT_PATHS[@]}"
check "use NavigationStack or NavigationSplitView, not NavigationView" \
    '\bNavigationView\b' "${SWIFT_PATHS[@]}"
check "use foregroundStyle(_:), not foregroundColor(_:)" \
    '\.foregroundColor\(' "${SWIFT_PATHS[@]}"
check "Core and Live hold no views; UI belongs in a feature" \
    "${import}SwiftUI\\b" ${core_paths[@]+"${core_paths[@]}"} ${live_paths[@]+"${live_paths[@]}"}
check "Core holds protocols, types, logic and mocks; system frameworks belong in Live" \
    "${import}(?:AppKit|IOKit|Network|Sparkle)\\b" ${core_paths[@]+"${core_paths[@]}"}
check "fix the isolation instead of silencing the compiler: an actor, a Sendable value, or state behind OSAllocatedUnfairLock" \
    '@unchecked\s+Sendable\b|nonisolated\(unsafe\)' "${SWIFT_PATHS[@]}"
check "pass models through initializers, not the environment: a missing argument fails the build, a missing environment object crashes at run time" \
    '\.environment\(\s*[A-Za-z_]|@Environment\([A-Z]\w*\.self\)' "${SWIFT_PATHS[@]}"
check "store a preference through PreferencesStore with a PreferenceKey, not @AppStorage: the model owns the value and a test swaps the store" \
    '@AppStorage\b' "${SWIFT_PATHS[@]}"
check "pass a service in through an initializer, not a static shared instance: a test cannot swap a singleton" \
    '\bstatic\s+(?:let|var)\s+shared\b' "${SWIFT_PATHS[@]}"
check "take the time from an injected Clock; only Live reads the system clock" \
    '\bDate\(\)|\bDate\.now\b' "${non_live_paths[@]}"
check "wait on what the test checks (await, confirmation, a mock clock), not Task.sleep: a sleep is slow and flaky" \
    '\bTask\.sleep\b' "${test_paths[@]}"
check "log with the module's Logger (Log.swift), not print: print reaches no log and ships in release builds" \
    '(?<![.\w])(?:print|debugPrint)\(' "${SWIFT_PATHS[@]}"
check "handle or throw the error instead of try!; in a test, use try #require or let the test throw" \
    '\btry!' "${SWIFT_PATHS[@]}"
# A control or modifier given a string literal looks it up in the app's bundle, not in the
# target's own catalog, so it shows the key in every language and nothing fails to compile.
check "a string literal here never translates: pass Text(\"…\", bundle: .module), in a label: closure for a control, or Text(verbatim:) for text that is not translated" \
    '\b(?:Button|Label|Toggle|Picker|Section|Menu|Link|NavigationLink|TextField|SecureField|DisclosureGroup|GroupBox|LabeledContent|Stepper|DatePicker|ColorPicker|ProgressView|ControlGroup|Tab|CommandMenu|Window|WindowGroup|MenuBarExtra)\(\s*"|\.(?:navigationTitle|navigationSubtitle|help|alert|confirmationDialog|badge|accessibilityLabel|accessibilityHint|accessibilityValue)\(\s*"|\b(?:Text\(|String\(localized:)\s*"(?:[^"\\]|\\.)*"\s*\)' \
    Sources/AppRoot Sources/Features

# Which targets may depend on which (Sources/AGENTS.md). Test targets depend on what they test.
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

# A target declared without swiftSettings builds with none of them: warnings pass, and its
# async functions run on another actor than in every other target. Package.swift's common
# treats warnings as errors and ui is common plus one setting, so that setting tells.
while read -r target; do
    [[ -n $target ]] || continue
    echo "error: $target has no swiftSettings in Package.swift; give it common, or ui for a target that draws views" >&2
    status=1
done < <(jq -r '.targets[] | select(.type == "regular" or .type == "test")
    | select([.settings[]? | .kind.treatAllWarnings._0] | index("error") | not) | .name' <<<"$package")

# Xcode's Test action lists test bundles by hand. A package test target the app scheme does
# not list is skipped without a word by ⌘U and xcodebuild test; SwiftPM runs it either way,
# so only this check can say so. A stale entry in the scheme needs no check: xcodebuild
# fails on it by name.
[[ -f $XCODE_SCHEME ]] || die "lint-rules.sh: no $XCODE_SCHEME; the scheme is named after APP_NAME in App/Configs/Identity.xcconfig"
listed=$(grep -B5 'ReferencedContainer = "container:\.\."' "$XCODE_SCHEME" |
    sed -nE 's/.*BlueprintIdentifier = "([^"]+)".*/\1/p' | sort -u)
declared=$(jq -r '.targets[] | select(.type == "test") | .name' <<<"$package" | sort -u)
while read -r target; do
    [[ -n $target ]] || continue
    echo "error: $target is not in the Test action of $XCODE_SCHEME, so ⌘U and xcodebuild test skip it silently; copy a TestableReference there and change its three names" >&2
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
    echo "error: Package.resolved and $xcode_resolved pin different versions; swift test and dependabot write the first, Xcode the second: copy the one with the versions you want over the other, then make test build" >&2
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
# Project.xcconfig has to set it; another xcconfig may, and then has to agree.
(deployment_target >/dev/null) || status=1
while read -r xcconfig; do
    value=$(deployment_target "$xcconfig" 2>/dev/null) || continue
    if [[ $(major_minor "$value") != "$(major_minor "$package_macos")" ]]; then
        echo "error: $xcconfig sets MACOSX_DEPLOYMENT_TARGET = $value, Package.swift .macOS $package_macos; change them together" >&2
        status=1
    fi
done < <(find App -name '*.xcconfig' | sort)

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

# template-only:start
# status.sh tells an app made from the template that its icon is still the template's, so
# its TEMPLATE_ICON follows the icon.
if ! grep -qx "TEMPLATE_ICON=$(icon_digest)" scripts/setup/status.sh; then
    echo "error: TEMPLATE_ICON in scripts/setup/status.sh is not the digest of App/Application/AppIcon.icon; set it to $(icon_digest)" >&2
    status=1
fi
if ! grep -qx "TEMPLATE_NAME=$APP_NAME" scripts/setup/status.sh; then
    echo "error: TEMPLATE_NAME in scripts/setup/status.sh is not APP_NAME ($APP_NAME); the project line reads it" >&2
    status=1
fi
# template-only:end

# Docs link only to files that exist and name only make targets that the Makefile defines.
# Tracked and new files alike, ignored ones (.build/) not. A skill's docs are its own
# business: the template checks the files it ships and the ones it owns.
docs=$(git ls-files --cached --others --exclude-standard -- '*.md' ':(exclude).agents/**' | sort -u)

# Every AGENTS.md has a CLAUDE.md beside it that only loads it.
while read -r doc; do
    [[ $(basename "$doc") == AGENTS.md ]] || continue
    claude="$(dirname "$doc")/CLAUDE.md"
    if [[ ! -f $claude || $(cat "$claude") != "@AGENTS.md" ]]; then
        echo "error: $doc needs a $claude beside it holding only the line @AGENTS.md" >&2
        status=1
    fi
done <<<"$docs"

# Relative links resolve; the #fragment is not checked.
while read -r doc; do
    [[ -n $doc ]] || continue
    while IFS=: read -r line target; do
        target=${target%%#*}
        [[ -n $target ]] || continue
        if [[ ! -e "$(dirname "$doc")/$target" ]]; then
            echo "error: $doc:$line links to $target, which does not exist" >&2
            status=1
        fi
    done < <(perl -ne 'while (/\]\(([^)\s]+)/g) { my $t = $1; print "$.:$t\n" unless $t =~ m{^(?:[a-z]+:|#|<)} }' "$doc")
done <<<"$docs"

# A make target named in the docs is one the Makefile defines, a step of make ci included:
# `make x` in text, or a line of a ``` block starting with make.
targets=$(sed -n 's/^\([a-z][a-z-]*\):.*/\1/p' Makefile | sort -u)
while read -r doc; do
    [[ -n $doc ]] || continue
    while IFS=: read -r line target; do
        if ! grep -qxF -- "$target" <<<"$targets"; then
            echo "error: $doc:$line names make $target, which the Makefile does not define" >&2
            status=1
        fi
    done < <(perl -ne '$fence = !$fence if /^\s*```/;
        my $start = $fence ? qr/^\s*(?:\$\s+)?|`/ : qr/`/;
        while (/(?:$start)make\s+([a-z][a-z:-]*[a-z])/g) { print "$.:$1\n" }' "$doc")
done <<<"$docs"

# The template describes itself. A skill may read the template; the template never reads a
# skill, so a moved skill takes nothing here with it and needs nothing here to work. A
# skill's own docs are the exception, and the .claude/ links into them; so is this file,
# which spells the pattern out.
if offenders=$(git ls-files --cached --others --exclude-standard -z -- ':(exclude).agents/**' ':(exclude).claude/**' ':(exclude)scripts/dev/lint-rules.sh' |
    xargs -0 grep -lE '\.agents/skills|\.claude/skills' 2>/dev/null); then
    echo "error: these files reach into a skill, which the template does not read; spell out the file rather than a skill path:" >&2
    echo "$offenders" | sed 's/^/  /' >&2
    status=1
fi

exit $status
