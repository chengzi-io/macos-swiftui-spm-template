import Testing

@testable import SettingsFeature

// The template ships one pane (Updates), so these cover the start state and the history
// rules that hold with any number of panes. Back and forward move between panes: with a
// second case added to `SettingsPane`, `open`, `goBack` and `goForward` are what to test.

@Test func settingsNavigationStartsOnTheGivenPane() {
    let navigation = SettingsNavigation(pane: .updates)
    #expect(navigation.pane == .updates)
    #expect(!navigation.canGoBack)
    #expect(!navigation.canGoForward)
}

@Test func settingsNavigationIgnoresTheCurrentPane() {
    let navigation = SettingsNavigation()
    navigation.open(.updates)
    #expect(!navigation.canGoBack)
    #expect(navigation.pane == .updates)
}

@Test func settingsNavigationDoesNotMovePastEitherEnd() {
    let navigation = SettingsNavigation()
    navigation.goBack()
    navigation.goForward()
    #expect(navigation.pane == SettingsPane.allCases[0])
}
