# Single entry point for people, agents and CI. Logic lives in scripts/;
# targets only orchestrate. Run `make help` for the list.

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

# App/<App>.xcodeproj names the app target and its scheme.
APP_TARGET := $(patsubst App/%.xcodeproj/project.pbxproj,%,$(wildcard App/*.xcodeproj/project.pbxproj))
ifneq ($(words $(APP_TARGET)),1)
$(error expected one Xcode project in App/, found: $(APP_TARGET))
endif
SWIFT_PATHS := Package.swift Sources Tests App
BUNDLE_ID := $(shell sed -nE 's/^BUNDLE_ID[[:space:]]*=[[:space:]]*//p' App/Configs/Identity.xcconfig)

.PHONY: help
help: ## List targets
	@awk '/^##@/ { printf "\n%s\n", substr($$0, 5) } /^([a-z-]|\\:)+:.*## / { match($$0, /^([a-z-]|\\:)+/); target = substr($$0, 1, RLENGTH); gsub(/\\/, "", target); split($$0, parts, "## "); printf "  %-18s %s\n", target, parts[2] }' $(MAKEFILE_LIST)

##@ Setup

# template-only:start
.PHONY: init
init: ## First run after "Use this template": ARGS="--name MyApp --bundle-id com.example.myapp"
	scripts/init.sh $(ARGS)
# template-only:end

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

.PHONY: test
test: ## Run the package unit tests with swift test (fast: no app, no UI)
	swift test

# Records the view snapshots that are missing or differ. A recording run reports each
# image it writes as an issue, so the second run is the one that has to pass. Agents run
# it only after the user has seen the old and new images (.claude/settings.json asks).
.PHONY: snapshots
snapshots: ## Record new and changed view snapshots in __Snapshots__/ (review them before committing)
	-SNAPSHOT_TESTING_RECORD=failed swift test
	swift test

# UI tests drive the real mouse and keyboard on this Mac, so they stay out of
# `make test` and `make ci`; GitHub CI runs them.
.PHONY: test\:ui
test\:ui: ## Run the UI tests; they take over the mouse and keyboard while they run
	xcodebuild test -quiet -project App/$(APP_TARGET).xcodeproj -scheme $(APP_TARGET) \
		-derivedDataPath .build/xcode -destination "platform=macOS,arch=$$(uname -m)" \
		-only-testing:$(APP_TARGET)UITests

.PHONY: fmt
fmt: ## Format Swift sources in place
	swift format format --in-place --recursive --parallel $(SWIFT_PATHS)

.PHONY: lint
lint: ## Check formatting, scripts/lint-rules.sh and the asset catalogs (fails on any finding)
	swift format lint --strict --recursive --parallel $(SWIFT_PATHS)
	scripts/lint-rules.sh
	scripts/lint-assets.sh

.PHONY: app
app: ## Build the debug .app with xcodebuild (ad-hoc signed)
	scripts/build-app.sh debug

.PHONY: run
run: ## Build and run the debug .app, logs in this terminal; pass ARGS="..."
	scripts/run.sh $(ARGS)

.PHONY: logs
logs: ## Stream this app's unified logs
	log stream --level debug --predicate 'subsystem == "$(BUNDLE_ID)"'

.PHONY: smoke
smoke: ## Smoke-test the debug .app (or APP=path)
	scripts/smoke.sh $(APP)

##@ Verify

.PHONY: ci
ci: lint test app smoke ## The definition of done; CI runs this, then make test:ui

##@ Release (CI runs `make release` after release-please creates the tag)

.PHONY: release-app
release-app: ## Build dist/<App>.app: universal, hardened runtime, signed
	scripts/build-app.sh release

.PHONY: release-dmg
release-dmg: ## Package dist/<App>.app into a DMG, sign and notarize it
	scripts/package-dmg.sh

.PHONY: appcast
appcast: ## Generate dist/appcast.xml for the DMG
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
