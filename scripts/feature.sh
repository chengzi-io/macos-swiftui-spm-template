#!/usr/bin/env bash
# Creates a feature's files and prints the blocks to paste into Package.swift, AppRoot and
# the app scheme. It changes no existing file: the targets, the wiring and the Test action
# stay a reviewed edit, and scripts/lint-rules.sh fails while a test target is missing from
# the scheme.

source "$(dirname "$0")/common.sh"

name=${NAME:-}
[[ -n $name ]] || die "usage: make feature NAME=Library"
[[ $name =~ ^[A-Z][A-Za-z0-9]*$ ]] ||
    die "NAME is the area's name and names its types: a capital letter, then letters and digits"
[[ $name != *Feature ]] || die "NAME is the area's name; its target is already named <Name>Feature"
[[ ! -e Sources/Features/$name ]] || die "Sources/Features/$name already exists"
[[ ! -e Tests/Features/${name}Tests ]] || die "Tests/Features/${name}Tests already exists"
if grep -q "name: \"${name}Feature\"" Package.swift; then
    die "Package.swift already declares ${name}Feature"
fi

log "create Sources/Features/$name"
mkdir -p "Sources/Features/$name/Resources"

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

cat <<EOF

Sources/Features/$name/
  ${name}Model.swift  ${name}View.swift  Resources/Localizable.xcstrings

Package.swift, in targets: (one item per line, sorted; add the Cores the feature uses to
dependencies:)
        .target(
            name: "${name}Feature",
            path: "Sources/Features/$name",
            resources: [.process("Resources")],
            swiftSettings: ui
        ),

Package.swift, AppRoot's dependencies:
                "${name}Feature",

Then AppModel owns ${name}Model and AppScenes shows ${name}View.

When Tests/Features/${name}Tests/ has a test file, add the test target and the scheme
entry; make lint fails until both are in:
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

App/${APP_TARGET}.xcodeproj/xcshareddata/xcschemes/${APP_TARGET}.xcscheme, in <Testables>:
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
