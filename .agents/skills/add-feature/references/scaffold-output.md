# What fails after `make feature`, and the fix

The scaffold's own output lists the files it wrote and the two lines to add; what it cannot
know is which check fails next.

| Failure | Fix |
| --- | --- |
| `make lint`: `<Name>FeatureTests is not in the Test action` | the scheme lacks the entry: copy another `<X>FeatureTests` `TestableReference` in it and change its three names |
| `make lint`: `has no <locale> translation` | translate every string in the feature's `Localizable.xcstrings` |
| `make lint`: `depends on <X>Feature` | a feature imports another; move the shared part into a domain's Core |
| `swift test`: `no such module` or an explicit-import error | the target's `dependencies` in `Package.swift` lack that module |
