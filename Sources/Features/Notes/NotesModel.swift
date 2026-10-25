import Foundation
import Notes
import OSLog
import Observation

@Observable
public final class NotesModel {
    public var text = ""
    public private(set) var isSaving = false
    public var errorMessage: String?

    private var savedText = ""
    private var hasLoaded = false
    private let service: any NoteService

    public init(service: any NoteService) {
        self.service = service
    }

    public var isSaved: Bool { text == savedText }
    public var wordCount: Int { WordCount.of(text) }

    /// Every window calls this as it appears; only the first call reads the note, so a
    /// new window keeps unsaved text.
    public func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        do {
            text = try await service.load()
            savedText = text
        } catch {
            Log.notes.error("load failed: \(String(describing: error), privacy: .public)")
            errorMessage = error.message
        }
    }

    /// One save at a time, so an older text never lands after a newer one.
    public func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let text = text
        do {
            try await service.save(text)
            savedText = text
        } catch {
            Log.notes.error("save failed: \(String(describing: error), privacy: .public)")
            errorMessage = error.message
        }
    }
}

extension NoteError {
    // Error types are nonisolated (Error is Sendable), so `LocalizedError` cannot read
    // `Bundle.module`, which the target's default isolation puts on MainActor.
    @MainActor var message: String {
        switch self {
        case .loadFailed: String(localized: "The note could not be opened.", bundle: .module)
        case .saveFailed: String(localized: "The note could not be saved.", bundle: .module)
        }
    }
}
