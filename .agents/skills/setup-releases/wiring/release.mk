# The release pipeline. The setup-releases skill copies this file to the repository
# root, whose Makefile includes it with `-include release.mk`; make help lists the
# targets below from then on. CI runs `make release` after release-please creates the tag.

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
