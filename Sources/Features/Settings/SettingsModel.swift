import Foundation
import Observation
import Platform

/// The Settings window's state. Each setting is a preference; one with an effect beyond
/// the stored value also goes to the service that applies it.
@Observable
public final class SettingsModel {
    public let updater: any UpdaterService
    /// The language the app runs in: the one set for it in System Settings, else the
    /// first of the Mac's languages it has.
    public let languageIdentifier: String

    public var appearance: Appearance {
        didSet {
            preferences[.appearance] = appearance
            appearanceService.apply(appearance)
        }
    }

    @ObservationIgnored private let preferences: any PreferencesStore
    @ObservationIgnored private let appearanceService: any AppearanceService

    /// Applies the saved appearance: `AppModel` builds this model at launch, so the first
    /// window already opens in it.
    public init(
        updater: any UpdaterService,
        preferences: any PreferencesStore,
        appearance: any AppearanceService,
        languageIdentifier: String = Bundle.main.preferredLocalizations.first ?? "en"
    ) {
        self.updater = updater
        self.preferences = preferences
        appearanceService = appearance
        self.languageIdentifier = languageIdentifier
        self.appearance = preferences[.appearance]
        appearance.apply(self.appearance)
    }

    /// The language's name in itself ("English", "简体中文"), as System Settings lists it.
    public var languageName: String {
        Locale(identifier: languageIdentifier).localizedString(forIdentifier: languageIdentifier)
            ?? languageIdentifier
    }
}
