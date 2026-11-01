# What users get

Without a Developer ID, releases are ad-hoc signed: no hardened runtime (its library
validation would reject the embedded Sparkle framework) and no notarization.

| What users get | Ad-hoc (default) | Developer ID |
| --- | --- | --- |
| First launch | Blocked by Gatekeeper, once: System Settings → Privacy & Security → **Open Anyway** | Opens |
| Updates through Sparkle | Work: EdDSA proves they came from you, and no Gatekeeper prompt | Work |
| Permissions (camera, screen recording, accessibility…) and keychain items | May be asked for again after an update: every build has a new signature | Kept |
| Homebrew cask (`setup-homebrew`) | Own tap only: blocked at first launch, or the cask clears the quarantine flag; `README.md` says which | Installs, and can go to the official `homebrew/cask` |
