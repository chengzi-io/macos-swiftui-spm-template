# Single entry point for people, agents and CI. Logic lives in scripts/;
# targets only orchestrate. Run `make help` for the list.

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

SWIFT_PATHS := Sources Tests Package.swift
ENV := source Bundle/app.env

.PHONY: help
help: ## List targets
	@awk 'BEGIN { FS = ":.*## " } /^##@/ { printf "\n%s\n", substr($$0, 5) } /^[a-z-]+:.*## / { printf "  %-18s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

##@ Setup

.PHONY: setup
setup: doctor ## Check the toolchain and install git hooks
	lefthook install

.PHONY: doctor
doctor: ## Check Xcode, tools and signing identity
	scripts/doctor.sh

##@ Develop

.PHONY: build
build: ## Compile with swift build (fast; not shippable)
	swift build

.PHONY: test
test: ## Run unit tests with swift test
	swift test

.PHONY: fmt
fmt: ## Format Swift sources in place
	swift format format --in-place --recursive --parallel $(SWIFT_PATHS)

.PHONY: lint
lint: ## Check formatting (fails on any finding)
	swift format lint --strict --recursive --parallel $(SWIFT_PATHS)

.PHONY: app
app: ## Build the debug .app (ad-hoc signed)
	scripts/build-app.sh debug

.PHONY: run
run: ## Build and run the debug .app, logs in this terminal; pass ARGS="..."
	scripts/run.sh $(ARGS)

.PHONY: logs
logs: ## Stream this app's unified logs
	@$(ENV) && log stream --level debug --predicate "subsystem == \"$$BUNDLE_ID\""

.PHONY: smoke
smoke: ## Smoke-test the debug .app (or APP=path)
	scripts/smoke.sh $(APP)

##@ Verify

.PHONY: ci
ci: lint test app smoke ## Everything CI runs; the definition of done

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
sparkle-keys: ## Create the Sparkle EdDSA key and write its public half to Bundle/app.env
	scripts/sparkle-keys.sh

.PHONY: clean
clean: ## Remove build output
	rm -rf .build dist
