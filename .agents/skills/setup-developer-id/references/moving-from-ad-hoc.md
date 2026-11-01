# Moving from ad-hoc

Keep the same Sparkle key: existing installs accept the first Developer ID update by its
EdDSA signature. This transition has not been exercised yet; try it with a test build
before relying on it.

Ad-hoc releases carry the first-launch note twice: `scripts/publish-github.sh` adds it to
each GitHub Release it publishes, and the `### First launch` subsection of `README.md`
carries it for the README. Step 7 of the skill removes the README one. The release notes
of releases already published stay as they are; a Developer ID release gets none.
