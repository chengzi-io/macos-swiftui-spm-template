# What the scaffold makes, and what fails later

The files `scaffold.sh` writes for `<Name>`, and the checks that fail after it.

| File | Holds |
| --- | --- |
| `Sources/Features/<Name>/<Name>Model.swift` | `@Observable` model; the screens' state and the state they share |
| `Sources/Features/<Name>/<Name>View.swift` | the view, taking its model through `init`, and a `#Preview` |
| `Sources/Features/<Name>/Log.swift` | `Log.<name>`, the module's `Logger` |
| `Sources/Features/<Name>/Resources/Localizable.xcstrings` | the view's strings; one `new` entry per `REQUIRED_LOCALES` locale |
| `Tests/Features/<Name>Tests/<Name>ViewRenderTests.swift` | renders the view light and dark into `.build/renders/` |
| `App/<App>.xcodeproj/xcshareddata/xcschemes/<App>.xcscheme` | gains a `<Name>FeatureTests` `TestableReference` |

| Failure | Fix |
| --- | --- |
| `make lint`: `<Name>FeatureTests is not in the Test action` | the scheme lacks the entry: copy another `<X>FeatureTests` `TestableReference` in it, or the one the scaffold printed, and change its three names |
| `make lint`: `has no <locale> translation` | translate every string in the feature's `Localizable.xcstrings` |
| `make lint`: `depends on <X>Feature` | a feature imports another; move the shared part into a domain's Core |
| `swift test`: `no such module` or an explicit-import error | the target's `dependencies` in `Package.swift` lack that module |
