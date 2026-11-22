import Platform
import Testing

@testable import SettingsFeature

@MainActor
struct SettingsModelTests {
    @Test func launchAppliesTheSavedAppearance() {
        let service = MockAppearanceService()
        let model = makeModel(preferences: MockPreferencesStore(values: ["appearance": "dark"]), appearance: service)
        #expect(model.appearance == .dark)
        #expect(service.applied == [.dark])
    }

    @Test func nothingSavedFollowsTheSystem() {
        let service = MockAppearanceService()
        let model = makeModel(appearance: service)
        #expect(model.appearance == .system)
        #expect(service.applied == [.system])
    }

    @Test func choosingAnAppearanceSavesAndAppliesIt() {
        let preferences = MockPreferencesStore()
        let service = MockAppearanceService()
        let model = makeModel(preferences: preferences, appearance: service)
        model.appearance = .light
        #expect(preferences[.appearance] == .light)
        #expect(service.applied == [.system, .light])
    }

    @Test(arguments: [("en", "English"), ("zh-Hans", "简体中文")])
    func languageIsNamedInItself(identifier: String, name: String) {
        #expect(makeModel(languageIdentifier: identifier).languageName == name)
    }

    private func makeModel(
        preferences: any PreferencesStore = MockPreferencesStore(),
        appearance: any AppearanceService = MockAppearanceService(),
        languageIdentifier: String = "en"
    ) -> SettingsModel {
        SettingsModel(
            updater: MockUpdaterService(),
            preferences: preferences,
            appearance: appearance,
            languageIdentifier: languageIdentifier
        )
    }
}
