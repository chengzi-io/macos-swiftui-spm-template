import Notes
import NotesFeature
import Observation
import Platform
import SettingsFeature

/// Root of the model tree: owns each feature's model and the services they share.
@Observable
public final class AppModel {
    public let notes: NotesModel
    public let settings: SettingsModel
    public let updater: any UpdaterService

    public init(
        noteService: any NoteService,
        updater: any UpdaterService,
        preferences: any PreferencesStore,
        appearance: any AppearanceService
    ) {
        notes = NotesModel(service: noteService)
        settings = SettingsModel(updater: updater, preferences: preferences, appearance: appearance)
        self.updater = updater
    }
}
