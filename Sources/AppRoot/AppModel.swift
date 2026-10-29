import Notes
import NotesFeature
import Observation
import Platform

/// Root of the model tree: owns each feature's model and the services they share.
@Observable
public final class AppModel {
    public let notes: NotesModel
    public let updater: any UpdaterService

    public init(noteService: any NoteService, updater: any UpdaterService) {
        notes = NotesModel(service: noteService)
        self.updater = updater
    }
}
