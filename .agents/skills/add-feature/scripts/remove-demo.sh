#!/usr/bin/env bash
# Removes the Notes demo, the first feature's place: the Notes domain and feature, their
# tests and UI test, their targets in Package.swift and the scheme's Test action.
# AppModel, AppScenes and MainApp.swift are rewritten to an empty window and Settings;
# a launch UI test replaces NotesUITests. Every step says "done already" once its result
# is in place, so the demo can go before the first feature is wired.
#
#   remove-demo.sh [--dry-run]

# shellcheck source=../../../../scripts/common.sh
source "$(dirname "$0")/../../../../scripts/common.sh"

dry_run=0
case ${1:-} in
    "") ;;
    --dry-run) dry_run=1 ;;
    *) sed -n '2,8p' "$0" | sed -E 's/^# ?//' >&2; exit 1 ;;
esac
scheme=$XCODE_SCHEME
[[ -f $scheme ]] || die "no $scheme"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# put FILE < content: writes FILE only when the content differs; prints what it did, or
# with --dry-run what it would do.
put() {
    local file=$1
    cat >"$TMP/new"
    if [[ -f $file ]] && cmp -s "$TMP/new" "$file"; then
        echo "   done already: $file" >&2
    elif ((dry_run == 1)); then
        if [[ -f $file ]]; then
            echo "   would edit: $file ($(diff "$file" "$TMP/new" | grep -c '^[<>]' || true) lines)" >&2
        else
            echo "   would create: $file" >&2
        fi
    else
        cat "$TMP/new" >"$file"
        echo "   wrote: $file" >&2
    fi
}

# run description command...: runs it, or with --dry-run says it would.
run() {
    local description=$1
    shift
    if ((dry_run == 1)); then
        echo "   would $description" >&2
    else
        "$@"
        echo "   $description" >&2
    fi
}

# The demo is gone once none of its files, targets or test bundles is left.
demo=0
[[ ! -d Sources/Features/Notes ]] || demo=1
if grep -qE 'name: "(Notes|NotesLive|NotesFeature|NotesTests|NotesFeatureTests)"' Package.swift; then
    demo=1
fi
if grep -qE 'BlueprintIdentifier = "(NotesTests|NotesFeatureTests)"' "$scheme"; then
    demo=1
fi
if ((demo == 0)); then
    log "the Notes demo is gone already; nothing to do"
    exit 0
fi

log "1/4 the demo's files"
for path in Sources/Domains/Notes Sources/Domains/NotesLive Sources/Features/Notes Tests/Domains/NotesTests Tests/Features/NotesTests App/UITests/NotesUITests.swift; do
    if [[ -e $path ]]; then
        run "remove $path" rm -rf "$path"
    else
        echo "   done already: $path" >&2
    fi
done

log "2/4 Package.swift: the Notes targets and their names in AppModules and AppRoot"
# Drops each .target(...)/.testTarget(...) block whose name is a Notes one.
awk '
    /^        \.(target|testTarget)\($/ { block = $0 "\n"; inblock = 1; drop = 0; next }
    inblock {
        block = block $0 "\n"
        if ($0 ~ /^            name: "(Notes|NotesLive|NotesFeature|NotesTests|NotesFeatureTests)",$/) drop = 1
        if ($0 == "        ),") { if (!drop) printf "%s", block; inblock = 0 }
        next
    }
    { print }
' Package.swift | sed -E 's/"Notes(Feature|Live)?", //g; s/, "Notes(Feature|Live)?"\]/]/g' >"$TMP/package"
put Package.swift <"$TMP/package"
if ((dry_run == 0)) && grep -n 'Notes' Package.swift >&2; then
    die "Package.swift still names Notes on the lines above; fix them, then run this again"
fi

log "3/4 $scheme: the Notes test bundles"
awk '
    /^         <TestableReference$/ { block = $0 "\n"; inblock = 1; drop = 0; next }
    inblock {
        block = block $0 "\n"
        if ($0 ~ /BlueprintIdentifier = "(NotesTests|NotesFeatureTests)"/) drop = 1
        if ($0 ~ /^         <\/TestableReference>$/) { if (!drop) printf "%s", block; inblock = 0 }
        next
    }
    { print }
' "$scheme" >"$TMP/scheme"
if command -v xmllint >/dev/null; then
    xmllint --noout "$TMP/scheme" || die "$scheme would stop being well-formed XML; left it alone"
fi
put "$scheme" <"$TMP/scheme"

log "4/4 AppModel, AppScenes, MainApp.swift and a launch UI test"
put Sources/AppRoot/AppModel.swift <<'SWIFT'
import Observation
import Platform

/// Root of the model tree: owns each feature's model and the services they share.
@Observable
public final class AppModel {
    public let updater: any UpdaterService

    public init(updater: any UpdaterService) {
        self.updater = updater
    }
}
SWIFT
put Sources/AppRoot/AppScenes.swift <<'SWIFT'
import SettingsFeature
import SwiftUI

/// Every window, menu command and the Settings scene. The app target's `@main`
/// only builds the services and hands them over.
public struct AppScenes: Scene {
    private let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some Scene {
        WindowGroup {
            // The first feature's view replaces this.
            Color.clear
                .frame(minWidth: 480, minHeight: 320)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesButton(updater: model.updater)
            }
        }
        Settings {
            SettingsView(updater: model.updater)
        }
    }
}
SWIFT
put App/Application/MainApp.swift <<'SWIFT'
import AppRoot
import Platform
import PlatformLive
import SwiftUI

/// Composition root: the only place that knows the live services.
@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = makeModel()

    var body: some Scene {
        AppScenes(model: model)
    }
}

/// UI tests launch with UI_TESTING=1: mocks only, no network or system side effects.
/// An environment variable, not an argument: AppKit reads `-key value` arguments as
/// defaults and opens a leftover argument as a file, and then no window appears.
/// Debug builds only: in a shipped app, an environment variable must not swap a live
/// service (a license check, say) for its mock.
private func makeModel() -> AppModel {
    #if DEBUG
        if ProcessInfo.processInfo.environment["UI_TESTING"] == "1" {
            return AppModel(updater: MockUpdaterService())
        }
    #endif
    return AppModel(updater: LiveUpdaterService())
}
SWIFT
put App/UITests/LaunchUITests.swift <<'SWIFT'
import XCTest

@MainActor
final class LaunchUITests: XCTestCase {
    func testOpensAWindow() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTING"] = "1"
        // A fresh launch, not the windows of the last session.
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }
}
SWIFT

if ((dry_run == 1)); then
    log "dry run done; nothing was changed"
else
    log "demo removed. AGENTS.md and docs still use Notes as their example: point them at the first real feature when it lands"
fi
