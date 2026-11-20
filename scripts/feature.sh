#!/usr/bin/env bash
# Creates a feature's files, its log and its render test, declares its targets in
# Package.swift and its test target in the app scheme, and prints the wiring left for the
# feature to work. The manifest edits go through `swift package add-target`, so SwiftPM
# parses the Swift, not this script; the wiring stays a reviewed edit. Run from anywhere
# inside the project.
#
#   feature.sh <Name> [Core...]    <Name> is the area's name: Library makes LibraryFeature;
#                                  each Core is a target its code uses, such as Notes

# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

name=${1:-}
cores=("${@:2}")
logger=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
[[ -n $name ]] || die "usage: scripts/feature.sh <Name> [Core...], such as Library Notes"
[[ $name =~ ^[A-Z][A-Za-z0-9]*$ ]] ||
    die "<Name> is the area's name and names its types: a capital letter, then letters and digits"
[[ $name != *Feature ]] || die "<Name> is the area's name, without Feature: ${name%Feature} makes the target $name"
# Log.<logger> has to be an identifier.
case $logger in
as | break | case | catch | class | continue | default | defer | deinit | do | else | enum | \
    extension | fallthrough | false | fileprivate | for | func | guard | if | import | in | init | \
    inout | internal | is | let | nil | open | operator | private | protocol | public | repeat | \
    rethrows | return | self | static | struct | subscript | super | switch | throw | throws | \
    true | try | typealias | var | where | while)
    die "$name would name the logger Log.$logger, a Swift keyword; pick another name"
    ;;
esac
[[ ! -e Sources/Features/$name ]] || die "Sources/Features/$name already exists"
[[ ! -e Tests/Features/${name}Tests ]] || die "Tests/Features/${name}Tests already exists"
for core in ${cores[@]+"${cores[@]}"}; do
    [[ $core =~ ^[A-Z][A-Za-z0-9]*$ ]] ||
        die "a Core is a target's name, a capital letter then letters and digits: $core"
done
if grep -q "name: \"${name}Feature\"" Package.swift; then
    die "Package.swift already declares ${name}Feature"
fi
[[ -f $XCODE_SCHEME ]] || die "no $XCODE_SCHEME"
if grep -q "BlueprintIdentifier = \"${name}FeatureTests\"" "$XCODE_SCHEME"; then
    die "$XCODE_SCHEME already lists ${name}FeatureTests"
fi
command -v xmllint >/dev/null || die "xmllint missing; it ships with macOS"

# Before the targets go into the manifest: `swift package dump-package` below reads them
# from disk, and a failure here leaves no half-written feature behind.
log "create Sources/Features/$name and Tests/Features/${name}Tests"
mkdir -p "Sources/Features/$name/Resources" "Tests/Features/${name}Tests"

# SwiftPM writes the targets into Package.swift itself: `add-target` appends the block,
# `add-target-dependency` the name in AppRoot's list. Parsing the manifest's Swift here is
# the alternative, and it breaks on a nested array or a comment.
log "Package.swift: ${name}Feature, ${name}FeatureTests and AppRoot's dependency"
feature_deps=()
if ((${#cores[@]} > 0)); then
    feature_deps=(--dependencies "${cores[@]}")
fi
swift package add-target "${name}Feature" --type library --path "Sources/Features/$name" \
    ${feature_deps[@]+"${feature_deps[@]}"} 1>&2
swift package add-target "${name}FeatureTests" --type test --testing-library swift-testing \
    --path "Tests/Features/${name}Tests" \
    --dependencies "${name}Feature" RenderSupport ${cores[@]+"${cores[@]}"} 1>&2
swift package add-target-dependency "${name}Feature" AppRoot 1>&2

# add-target writes its stub at Sources/<Target>, taking --path for the manifest alone, so
# what it made there goes and the directories above stay.
for stray in "Sources/${name}Feature" "Tests/${name}FeatureTests"; do
    [[ ! -e $stray ]] || rm -rf "$stray"
done

# add-target has no flag for a target's resources or swiftSettings, and SwiftPM has no
# command for either: the view finds its catalog through Bundle.module, which a target has
# only with resources, and both targets draw, so both need ui.
add_manifest_lines() {
    perl -0pi -e 's/(            name: "'"$1"'",\n(?:            .*\n)*?            path: "[^"]+")\n/$1,\n'"$2"'\n/' Package.swift
}
add_manifest_lines "${name}Feature" '            resources: [.process("Resources")],
            swiftSettings: ui'
add_manifest_lines "${name}FeatureTests" '            swiftSettings: ui'
# add-target-dependency writes .target(name: "X"); every other entry is a plain name.
perl -pi -e 's/\.target\(name: "'"${name}Feature"'"\)/"'"${name}Feature"'"/g' Package.swift
# Multi-element arrays get no trailing comma from add-target, and lint-rules.sh would say
# so one run later.
swift format format --in-place Package.swift

manifest=$(swift package dump-package) || die "Package.swift no longer loads; git diff it"
for target in "${name}Feature" "${name}FeatureTests"; do
    jq -e --arg target "$target" \
        'any(.targets[] | select(.name == $target) | .settings[]?; .kind.defaultIsolation? != null)' \
        <<<"$manifest" >/dev/null ||
        die "Package.swift: $target has no swiftSettings: ui; add it there by hand"
done

cat >"Sources/Features/$name/Log.swift" <<EOF
import Foundation
import OSLog

nonisolated enum Log {
    // Unbundled runs (\`swift test\`) have no bundle identifier.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "unbundled"

    static let ${logger} = Logger(subsystem: subsystem, category: "${logger}")
}
EOF

cat >"Sources/Features/$name/${name}Model.swift" <<EOF
import Observation

@Observable
public final class ${name}Model {
    public init() {}
}
EOF

cat >"Sources/Features/$name/${name}View.swift" <<EOF
import SwiftUI

public struct ${name}View: View {
    private let model: ${name}Model

    public init(model: ${name}Model) {
        self.model = model
    }

    public var body: some View {
        Text("${name}", bundle: .module)
            .padding()
    }
}

#Preview {
    ${name}View(model: ${name}Model())
}
EOF

# The view's one string, with an entry for each locale of REQUIRED_LOCALES but the source
# language, marked new: make lint fails until each is translated.
{
    printf '{\n  "sourceLanguage" : "en",\n  "strings" : {\n    "%s" : {\n' "$name"
    translations=()
    for locale in ${REQUIRED_LOCALES:-en}; do
        [[ $locale == en ]] || translations+=("$locale")
    done
    if ((${#translations[@]} == 0)); then
        printf '\n'
    else
        printf '      "localizations" : {\n'
        for i in "${!translations[@]}"; do
            separator=,
            ((i < ${#translations[@]} - 1)) || separator=
            printf '        "%s" : {\n          "stringUnit" : {\n            "state" : "new",\n            "value" : "%s"\n          }\n        }%s\n' \
                "${translations[$i]}" "$name" "$separator"
        done
        printf '      }\n'
    fi
    printf '    }\n  },\n  "version" : "1.0"\n}\n'
} >"Sources/Features/$name/Resources/Localizable.xcstrings"

cat >"Tests/Features/${name}Tests/${name}ViewRenderTests.swift" <<EOF
import AppKit
import RenderSupport
import Testing

@testable import ${name}Feature

@MainActor
struct ${name}ViewRenderTests {
    @Test func view() throws {
        try render(${name}View(model: ${name}Model()))
    }

    @Test func viewDark() throws {
        try render(${name}View(model: ${name}Model()), appearance: .darkAqua)
    }
}
EOF

# The scheme is the one shared file where the edit is mechanical: no ordering, no review
# value. Insert before </Testables>, then keep the file only if it is still valid XML.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/block" <<EOF
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "${name}FeatureTests"
               BuildableName = "${name}FeatureTests"
               BlueprintName = "${name}FeatureTests"
               ReferencedContainer = "container:..">
            </BuildableReference>
         </TestableReference>
EOF
line=$(grep -n '^      </Testables>$' "$XCODE_SCHEME" | cut -d: -f1)
[[ -n $line ]] || die "$XCODE_SCHEME has no </Testables> line; add the TestableReference by hand"
{
    head -n $((line - 1)) "$XCODE_SCHEME"
    cat "$tmp/block"
    tail -n +"$line" "$XCODE_SCHEME"
} >"$tmp/scheme"
xmllint --noout "$tmp/scheme" || die "$XCODE_SCHEME would stop being well-formed XML; left it alone"
mv "$tmp/scheme" "$XCODE_SCHEME"
log "add ${name}FeatureTests to $XCODE_SCHEME"

cat <<EOF

Sources/Features/$name/
  Log.swift  ${name}Model.swift  ${name}View.swift  Resources/Localizable.xcstrings
Tests/Features/${name}Tests/
  ${name}ViewRenderTests.swift
Package.swift and the scheme: written.

Wire it, each file also importing ${name}Feature:
  AppRoot/AppModel.swift, beside the other feature models
      public let ${logger} = ${name}Model()
  AppRoot/AppScenes.swift, in the scene that shows it
      ${name}View(model: model.${logger})

A Core it needs later: swift package add-target-dependency <Core> ${name}Feature

Translate "${name}" in Resources/Localizable.xcstrings for ${REQUIRED_LOCALES:-en}: make lint
fails while one is new. make test then draws the view into .build/renders/.
EOF
