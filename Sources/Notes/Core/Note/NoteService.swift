public enum NoteError: Error {
    case loadFailed(any Error)
    case saveFailed(any Error)
}

/// Reads and writes the one note.
public protocol NoteService: Sendable {
    func load() async throws(NoteError) -> String
    func save(_ text: String) async throws(NoteError)
}

/// Keeps the note in memory, for previews, tests and UI test launches (`UI_TESTING=1`).
/// With a `failure`, the call it names throws it: `.loadFailed` from `load()`,
/// `.saveFailed` from `save(_:)`.
public actor MockNoteService: NoteService {
    public private(set) var text: String
    private let failure: NoteError?

    public init(text: String = "", failure: NoteError? = nil) {
        self.text = text
        self.failure = failure
    }

    public func load() throws(NoteError) -> String {
        if let failure, case .loadFailed = failure { throw failure }
        return text
    }

    public func save(_ text: String) throws(NoteError) {
        if let failure, case .saveFailed = failure { throw failure }
        self.text = text
    }
}
