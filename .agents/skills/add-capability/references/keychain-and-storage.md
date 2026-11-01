# Keychain, structured data and files

- Tokens and passwords: Keychain through `SecItemAdd` / `SecItemCopyMatching` in a
  small service. Ad-hoc builds change signature on every update, so the keychain may
  ask the user to allow access again
  ([setup-developer-id, What users get](../../setup-developer-id/references/what-users-get.md#what-users-get)).
- Structured data: [swiftdata.md](swiftdata.md).
- Plain files: `URL.applicationSupportDirectory`, which resolves inside
  `~/Library/Containers/<bundle id>/Data/` under the sandbox.
