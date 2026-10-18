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

.PHONY: clean
clean: ## Remove build output
	rm -rf .build dist
