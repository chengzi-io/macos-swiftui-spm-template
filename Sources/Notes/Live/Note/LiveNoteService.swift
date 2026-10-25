import Foundation
import Notes

/// Keeps the note in a text file in Application Support, which the sandbox puts in the
/// app's container.
public struct LiveNoteService: NoteService {
    private let url = URL.applicationSupportDirectory.appending(path: "note.txt")

    public init() {}

    @concurrent
    public func load() async throws(NoteError) -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch CocoaError.fileReadNoSuchFile {
            return ""
        } catch {
            throw .loadFailed(error)
        }
    }

    @concurrent
    public func save(_ text: String) async throws(NoteError) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw .saveFailed(error)
        }
    }
}
