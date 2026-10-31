import Foundation
import Notes
import NotesLive
import Testing

/// The live service against the file system, each test in a directory of its own: what
/// a mock cannot show is how the service reads the files it finds.
struct LiveNoteServiceTests {
    let url = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "note.txt")

    @Test func missingFileIsAnEmptyNote() async throws {
        #expect(try await LiveNoteService(url: url).load() == "")
    }

    @Test func savedTextLoadsBack() async throws {
        let service = LiveNoteService(url: url)
        try await service.save("Grapefruit")
        #expect(try await service.load() == "Grapefruit")
    }

    @Test func unreadableFileFailsToLoad() async throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        await #expect(throws: NoteError.self) {
            try await LiveNoteService(url: url).load()
        }
    }
}
