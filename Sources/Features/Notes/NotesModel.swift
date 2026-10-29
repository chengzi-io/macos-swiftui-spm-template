import Foundation
import Notes
import OSLog
import Observation

@Observable
public final class NotesModel {
    public var text = ""
    /// Editing and saving wait for it: saving a note that could not be read would replace
    /// it.
    public private(set) var isLoaded = false
    public private(set) var isSaving = false
    public var errorMessage: String?

    private var savedText = ""
    private var isLoading = false
    private let service: any NoteService

    public init(service: any NoteService) {
        self.service = service
    }

    public var isSaved: Bool { text == savedText }
    public var wordCount: Int { WordCount.of(text) }

    /// Every window calls this as it appears; once the note is read, later calls do
    /// nothing, so a new window keeps unsaved text. After a failure the next window tries
    /// again.
    public func load() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            text = try await service.load()
            savedText = text
            isLoaded = true
        } catch {
            Log.notes.error("load failed: \(String(describing: error))")
            errorMessage = error.message
        }
    }

    /// One save at a time, so an older text never lands after a newer one.
    public func save() async {
        guard isLoaded, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let text = text
        do {
            try await service.save(text)
            savedText = text
        } catch {
            Log.notes.error("save failed: \(String(describing: error))")
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
