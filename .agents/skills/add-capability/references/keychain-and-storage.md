# Keychain, structured data and files

- Tokens and passwords: Keychain through `SecItemAdd` / `SecItemCopyMatching` in a
  small service. Ad-hoc builds change signature on every update, so the keychain may
  ask the user to allow access again. A Developer ID signed, notarized release keeps
  those items.
- Structured data: [swiftdata.md](swiftdata.md).
- Plain files: `URL.applicationSupportDirectory`, which resolves inside
  `~/Library/Containers/<bundle id>/Data/` under the sandbox.
