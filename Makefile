# Single entry point for people, agents and CI. Logic lives in scripts/;
# targets only orchestrate. Run `make help` for the list.

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help
# Targets list their steps in order (ci: versions lint test assets app smoke); make -j would run smoke
# against the previous build's app.
.NOTPARALLEL:

# App/<App>.xcodeproj names the app target and its scheme.
APP_TARGET := $(patsubst App/%.xcodeproj/project.pbxproj,%,$(wildcard App/*.xcodeproj/project.pbxproj))
ifneq ($(words $(APP_TARGET)),1)
$(error expected one Xcode project in App/, found: $(APP_TARGET))
endif
SWIFT_PATHS := Package.swift Sources Tests App
# Fails on an import of a module the target does not declare, as Package.swift's
# dependencies would otherwise be enforced only by build order.
SWIFT_TEST := swift test --explicit-target-dependency-import-check error
BUNDLE_ID := $(shell sed -nE 's/^BUNDLE_ID[[:space:]]*=[[:space:]]*//p' App/Configs/Identity.xcconfig)

.PHONY: help
help: ## List targets
	@awk '/^##@/ { printf "\n%s\n", substr($$0, 5) } /^([a-z-]|\\:)+:.*## / { match($$0, /^([a-z-]|\\:)+/); target = substr($$0, 1, RLENGTH); gsub(/\\/, "", target); split($$0, parts, "## "); printf "  %-18s %s\n", target, parts[2] }' $(MAKEFILE_LIST)

##@ Setup

.PHONY: setup
setup: doctor ## Check the toolchain and install git hooks
	lefthook install

.PHONY: doctor
doctor: ## Check Xcode, tools and signing identity
	scripts/doctor.sh

.PHONY: github-setup
github-setup: ## One-time GitHub settings: squash only, branch protection, release environment
	scripts/github-setup.sh

##@ Develop

# The view render tests write .build/renders/; clear the last run's, so a removed test
# leaves no image behind.
.PHONY: test
test: ## Run the package unit tests with swift test (fast: no app, no UI)
	rm -rf .build/renders
	$(SWIFT_TEST)

# Creates a feature's files and adds its test target to the app scheme; the Package.swift
# blocks and the wiring are printed, not applied, so they stay a reviewed edit.
.PHONY: feature
feature: ## Scaffold a feature's files: NAME=Library (prints the blocks to paste)
	scripts/feature.sh

# UI tests drive the real mouse and keyboard on this Mac, so they stay out of
# `make test` and `make ci`; GitHub CI runs them. The result bundle holds the failure
# screenshots; xcodebuild refuses to overwrite one, so the last run's goes first.
UI_TEST_RESULTS := .build/UITests.xcresult
.PHONY: test\:ui
test\:ui: ## Run the UI tests; they take over the mouse and keyboard while they run
	rm -rf $(UI_TEST_RESULTS)
	xcodebuild test -quiet -project App/$(APP_TARGET).xcodeproj -scheme $(APP_TARGET) \
		-derivedDataPath .build/xcode -destination "platform=macOS,arch=$$(uname -m)" \
		-resultBundlePath $(UI_TEST_RESULTS) \
		-only-testing:$(APP_TARGET)UITests

.PHONY: fmt
fmt: ## Format Swift sources in place
	swift format format --in-place --recursive --parallel $(SWIFT_PATHS)

.PHONY: lint
lint: ## Check formatting and scripts/lint-rules.sh (fails on any finding)
	swift format lint --strict --recursive --parallel $(SWIFT_PATHS)
	scripts/lint-rules.sh

# actool runs through a long-lived ibtoold, too slow and flaky for the lint loop.
.PHONY: assets
assets: ## Compile the asset catalog and AppIcon.icon with actool (fails on any warning)
	scripts/lint-assets.sh

.PHONY: app
app: ## Build the debug .app with xcodebuild (ad-hoc signed)
	scripts/build-app.sh debug

.PHONY: run
run: ## Build and run the debug .app, logs in this terminal; pass ARGS="..."
	scripts/run.sh $(ARGS)

.PHONY: logs
logs: ## Stream this app's unified logs, Sparkle's included
	log stream --level debug --predicate 'subsystem == "$(BUNDLE_ID)" || subsystem == "org.sparkle-project.Sparkle"'

.PHONY: smoke
smoke: ## Smoke-test the debug .app (or APP=path)
	scripts/smoke.sh $(APP)

##@ Verify

# First in make ci, so a local log and a CI log say which toolchain they came from.
.PHONY: versions
versions: ## Print the macOS, the selected Xcode and the pinned .xcode-version
	@echo "macOS $$(sw_vers -productVersion) ($$(sw_vers -buildVersion))"
	@xcodebuild -version | paste -sd ' ' -
	@echo ".xcode-version $$(cat .xcode-version 2>/dev/null || echo '(missing)')"

.PHONY: ci
ci: versions lint test assets app smoke ## The definition of done; CI runs this, then make test:ui

##@ Release (CI runs `make release` after release-please creates the tag)

# The steps of make release, for rerunning one by hand; make help leaves them out.
# release-app: dist/<App>.app, universal, hardened runtime, signed.
.PHONY: release-app
release-app:
	scripts/build-app.sh release

# release-dmg: dist/<App>.app into a DMG, signed and notarized.
.PHONY: release-dmg
release-dmg:
	scripts/package-dmg.sh

# appcast: dist/appcast.xml for the DMG.
.PHONY: appcast
appcast:
	scripts/appcast.sh

.PHONY: release
release: ## Full release into dist/: app, notarization, DMG, dSYM, appcast, checksums
	scripts/release.sh

.PHONY: sparkle-keys
sparkle-keys: ## Create the Sparkle EdDSA key and write its public half to App/Configs/Info.plist
	scripts/sparkle-keys.sh

.PHONY: clean
clean: ## Remove build output
	rm -rf .build dist
