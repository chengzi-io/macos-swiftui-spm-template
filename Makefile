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

# make help lists the entry points only; help itself stays off the list, which `make`
# alone still prints.
.PHONY: help
help:
	@awk '/^##@/ { printf "\n%s\n", substr($$0, 5) } /^([a-z-]+):.*## / { match($$0, /^([a-z-]+)/); target = substr($$0, 1, RLENGTH); split($$0, parts, "## "); printf "  %-18s %s\n", target, parts[2] }' $(MAKEFILE_LIST)

##@ Start

.PHONY: setup
setup: doctor ## Check the toolchain and install git hooks (once per clone)
	lefthook install

.PHONY: status
status: ## Where the project stands and what comes next
	scripts/setup/status.sh

.PHONY: run
run: ## Build and run the debug app; ARGS="..."
	scripts/dev/run.sh $(ARGS)

##@ Develop

# The view render tests write .build/renders/; clear the last run's, so a removed test
# leaves no image behind. FILTER narrows the run to the suites its regex matches
# (`make test FILTER=Notes`); the images go either way, so none survives a run that did
# not draw it. The import check fails on an import of a module the target does not
# declare, as Package.swift's dependencies would otherwise be enforced only by build order.
.PHONY: test
test: ## Unit and render tests, in seconds; FILTER=<regex>
	rm -rf .build/renders
	swift test --explicit-target-dependency-import-check error $(if $(FILTER),--filter '$(FILTER)')

.PHONY: fmt
fmt: ## Format Swift sources
	$(COMMON) && swift format format --in-place --recursive --parallel "$${SWIFT_PATHS[@]}"

.PHONY: lint
lint: ## Formatting and the project's rules
	scripts/dev/lint-rules.sh

# Scaffolding a feature is how a person adds one: the script writes the files, declares
# the targets and the scheme entry, and prints the two lines that wire it. NAME is the
# area (Library), CORES the targets its code uses ("Notes Platform").
.PHONY: feature
feature: ## Add a <Name>Feature target; NAME=<Area> CORES="..."
	@[[ -n "$(strip $(NAME))" ]] || { echo 'usage: make feature NAME=<Area> [CORES="<Core> ..."]' >&2; exit 1; }
	scripts/dev/feature.sh $(strip $(NAME)) $(strip $(CORES))

.PHONY: ci
ci: lint test lint-assets build smoke ## The definition of done: lint, test, assets, build, smoke

# Steps of make ci, kept for rerunning one by hand; make help leaves them out.
# actool runs through a long-lived ibtoold, too slow and flaky for the lint loop.
.PHONY: lint-assets
lint-assets:
	scripts/dev/lint-assets.sh

.PHONY: build
build:
	scripts/dev/build.sh

.PHONY: smoke
smoke:
	scripts/dev/smoke.sh $(APP)

# UI tests drive the real mouse and keyboard on this Mac, so they stay out of
# `make test` and `make ci`; GitHub CI runs them. The result bundle holds the failure
# screenshots; xcodebuild refuses to overwrite one, so the last run's goes first.
UI_TEST_RESULTS := .build/UITests.xcresult
.PHONY: test-ui
test-ui: ## UI tests; they take over the mouse and keyboard
	rm -rf $(UI_TEST_RESULTS)
	$(COMMON) && xcodebuild test -quiet -project "$$XCODE_PROJECT" -scheme "$$XCODE_SCHEME_NAME" \
		-derivedDataPath "$$DERIVED_DATA" -destination "platform=macOS,arch=$$(uname -m)" \
		-resultBundlePath $(UI_TEST_RESULTS) \
		-only-testing:AppUITests

.PHONY: doctor
doctor: ## Check Xcode, tools and signing identity
	scripts/setup/doctor.sh

.PHONY: clean
clean: ## Remove build output
	rm -rf .build dist

##@ Repository and release

.PHONY: github-settings
github-settings: ## Merge rules, branch protection and security settings
	scripts/setup/github-settings.sh

.PHONY: sparkle-key
sparkle-key: ## Create or restore the update-signing key (once per app); RESTORE=<file>
	scripts/setup/sparkle-key.sh $(if $(strip $(RESTORE)),restore '$(strip $(RESTORE))',create)

.PHONY: release
release: ## Full release build into dist/ (the Release workflow runs it)
	scripts/release/build.sh
