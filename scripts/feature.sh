#!/usr/bin/env bash
# Creates a feature's files, its log and its snapshot test, adds its test target to the app
# scheme, and prints the blocks to paste into Package.swift and AppRoot. Those stay a
# reviewed edit: they are Swift, shared by every branch, and scripts/lint-rules.sh fails
# while the scheme and Package.swift disagree.

source "$(dirname "$0")/common.sh"

name=${NAME:-}
logger=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
[[ -n $name ]] || die "usage: make feature NAME=Library"
[[ $name =~ ^[A-Z][A-Za-z0-9]*$ ]] ||
    die "NAME is the area's name and names its types: a capital letter, then letters and digits"
[[ $name != *Feature ]] || die "NAME is the area's name; its target is already named <Name>Feature"
# Log.<logger> has to be an identifier.
case $logger in
    as | break | case | catch | class | continue | default | defer | deinit | do | else | enum \
    | extension | fallthrough | false | fileprivate | for | func | guard | if | import | in | init \
    | inout | internal | is | let | nil | open | operator | private | protocol | public | repeat \
    | rethrows | return | self | static | struct | subscript | super | switch | throw | throws \
    | true | try | typealias | var | where | while)
        die "NAME=$name would name the logger Log.$logger, a Swift keyword; pick another name"
        ;;
esac
[[ ! -e Sources/Features/$name ]] || die "Sources/Features/$name already exists"
[[ ! -e Tests/Features/${name}Tests ]] || die "Tests/Features/${name}Tests already exists"
if grep -q "name: \"${name}Feature\"" Package.swift; then
    die "Package.swift already declares ${name}Feature"
fi
scheme="$XCODE_PROJECT/xcshareddata/xcschemes/$APP_TARGET.xcscheme"
[[ -f $scheme ]] || die "no $scheme"
if grep -q "BlueprintIdentifier = \"${name}FeatureTests\"" "$scheme"; then
    die "$scheme already lists ${name}FeatureTests"
fi
command -v xmllint >/dev/null || die "xmllint missing; it ships with macOS"

log "create Sources/Features/$name and Tests/Features/${name}Tests"
mkdir -p "Sources/Features/$name/Resources" "Tests/Features/${name}Tests"

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

cat >"Sources/Features/$name/Resources/Localizable.xcstrings" <<EOF
{
  "sourceLanguage" : "en",
  "strings" : {
    "${name}" : {
      "localizations" : {
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "new",
            "value" : "${name}"
          }
        }
      }
    }
  },
  "version" : "1.0"
}
EOF

cat >"Tests/Features/${name}Tests/${name}ViewSnapshotTests.swift" <<EOF
import AppKit
import SnapshotSupport
import SnapshotTesting
import Testing

@testable import ${name}Feature

@MainActor
@Suite(.snapshots(record: recording))
struct ${name}ViewSnapshotTests {
    @Test func view() throws {
        assertSnapshot(
            of: try render(${name}View(model: ${name}Model())),
            as: .image(perceptualPrecision: 0.98)
        )
    }

    @Test func viewDark() throws {
        assertSnapshot(
            of: try render(${name}View(model: ${name}Model()), appearance: .darkAqua),
            as: .image(perceptualPrecision: 0.98)
        )
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
line=$(grep -n '^      </Testables>$' "$scheme" | cut -d: -f1)
[[ -n $line ]] || die "$scheme has no </Testables> line; add the TestableReference by hand"
{
    head -n $((line - 1)) "$scheme"
    cat "$tmp/block"
    tail -n +"$line" "$scheme"
} >"$tmp/scheme"
xmllint --noout "$tmp/scheme" || die "$scheme would stop being well-formed XML; left it alone"
mv "$tmp/scheme" "$scheme"
log "add ${name}FeatureTests to $scheme"

cat <<EOF

Sources/Features/$name/
  Log.swift  ${name}Model.swift  ${name}View.swift  Resources/Localizable.xcstrings
Tests/Features/${name}Tests/
  ${name}ViewSnapshotTests.swift

Package.swift, in targets: (one item per line, sorted; add the Cores the feature uses to
dependencies:)
        .target(
            name: "${name}Feature",
            path: "Sources/Features/$name",
            resources: [.process("Resources")],
            swiftSettings: ui
        ),

Package.swift, the test target:
        .testTarget(
            name: "${name}FeatureTests",
            dependencies: [
                "${name}Feature",
                "SnapshotSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/Features/${name}Tests",
            exclude: ["__Snapshots__"],
            swiftSettings: ui
        ),

Package.swift, AppRoot's dependencies:
                "${name}Feature",

Then AppModel owns ${name}Model and AppScenes shows ${name}View.

The scheme already lists ${name}FeatureTests; the entry does nothing until Package.swift
declares the test target. make test then fails with "No reference was found": show the two
images it drew, and after a yes run make snapshots.
EOF
