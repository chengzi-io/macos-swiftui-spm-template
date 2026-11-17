import Testing

@testable import SettingsFeature

// `swift test` does not compile the string catalog, so titles and keywords are the
// English keys here.

@Test func settingsPaneMatchingFindsTitlesAndKeywords() {
    #expect(SettingsPane.matching("updates") == [.updates])
    #expect(SettingsPane.matching("VERSION") == [.updates])
}

@Test func settingsPaneMatchingTreatsABlankQueryAsEverything() {
    #expect(SettingsPane.matching("  ") == SettingsPane.allCases)
}

@Test func settingsPaneMatchingCanFindNothing() {
    #expect(SettingsPane.matching("zzz").isEmpty)
}
