# Single entry point for people, agents and CI. Logic lives in scripts/;
# targets only orchestrate. Run `make help` for the list.

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help
# Steps run in the order they are listed (make ci); make -j would run smoke against the
# previous build's app.
.NOTPARALLEL:

# A recipe that needs the app identity, the Xcode project or the Swift paths sources
# scripts/common.sh, which reads them and fails clearly when the project is missing.
COMMON := source scripts/common.sh
# Fails on an import of a module the target does not declare, as Package.swift's
# dependencies would otherwise be enforced only by build order.
SWIFT_TEST := swift test --explicit-target-dependency-import-check error

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

.PHONY: status
status: ## Show where the project stands, from template to release, and what comes next
	scripts/status.sh

.PHONY: github-settings
github-settings: ## Set the GitHub repository's merge, branch protection and security settings
	scripts/github-settings.sh

##@ Develop

# The view render tests write .build/renders/; clear the last run's, so a removed test
# leaves no image behind. FILTER narrows the run to the suites its regex matches
# (`make test FILTER=Notes`); the images go either way, so none survives a run that did
# not draw it.
.PHONY: test
test: ## Run the package unit tests with swift test (fast: no app, no UI); FILTER=<regex> for some suites
	rm -rf .build/renders
	$(SWIFT_TEST) $(if $(FILTER),--filter '$(FILTER)')

# UI tests drive the real mouse and keyboard on this Mac, so they stay out of
# `make test` and `make ci`; GitHub CI runs them. The result bundle holds the failure
# screenshots; xcodebuild refuses to overwrite one, so the last run's goes first.
UI_TEST_RESULTS := .build/UITests.xcresult
.PHONY: test\:ui
test\:ui: ## Run the UI tests; they take over the mouse and keyboard while they run
	rm -rf $(UI_TEST_RESULTS)
	$(COMMON) && xcodebuild test -quiet -project "$$XCODE_PROJECT" -scheme "$$APP_NAME" \
		-derivedDataPath .build/xcode -destination "platform=macOS,arch=$$(uname -m)" \
		-resultBundlePath $(UI_TEST_RESULTS) \
		-only-testing:AppUITests

.PHONY: fmt
fmt: ## Format Swift sources in place
	$(COMMON) && swift format format --in-place --recursive --parallel "$${SWIFT_PATHS[@]}"

# Scaffolding a feature is how a person adds one: the script writes the files, declares
# the targets and the scheme entry, and prints the two lines that wire it. NAME is the
# area (Library), CORES the targets its code uses ("Notes Platform").
.PHONY: feature
feature: ## Add a <Name>Feature target; NAME=<Area> CORES="<Core> ..."
	@[[ -n "$(strip $(NAME))" ]] || { echo 'usage: make feature NAME=<Area> [CORES="<Core> ..."]' >&2; exit 1; }
	scripts/feature.sh $(strip $(NAME)) $(strip $(CORES))

.PHONY: lint
lint: ## Check formatting and the rules in scripts/lint-rules.sh (fails on any finding)
	scripts/lint-rules.sh

# actool runs through a long-lived ibtoold, too slow and flaky for the lint loop.
.PHONY: lint\:assets
lint\:assets: ## Compile the asset catalog and AppIcon.icon with actool (fails on any warning)
	scripts/lint-assets.sh

.PHONY: build
build: ## Build the debug .app with xcodebuild (ad-hoc signed)
	scripts/build.sh debug

.PHONY: run
run: ## Build and run the debug .app, logs in this terminal; pass ARGS="..."
	scripts/run.sh $(ARGS)

.PHONY: smoke
smoke: ## Smoke-test the debug .app (or APP=path)
	scripts/smoke.sh $(APP)

##@ Verify

# CI runs make doctor before it, so the log says which toolchain the run used. The steps
# are goals of one sub-make, not prerequisites: make 3.81, the one macOS ships, keeps the
# backslash of lint\:assets in a prerequisite and never finds the target.
.PHONY: ci
ci: ## The definition of done; CI runs make doctor, this, then make test:ui
	@$(MAKE) --no-print-directory lint test lint:assets build smoke

.PHONY: clean
clean: ## Remove build output
	rm -rf .build dist

# The release targets live in release.mk, once the release pipeline is installed.
-include release.mk
