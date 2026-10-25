import Foundation
import Notes
import Testing

@testable import NotesFeature

@MainActor
struct NotesModelTests {
    @Test func loadShowsTheSavedNote() async {
        let model = NotesModel(service: MockNoteService(text: "Pomelo"))
        await model.load()
        #expect(model.text == "Pomelo")
        #expect(model.isSaved)
    }

    @Test func saveStoresTheText() async {
        let service = MockNoteService()
        let model = NotesModel(service: service)
        await model.load()
        model.text = "Pomelo"
        #expect(!model.isSaved)
        await model.save()
        #expect(await service.text == "Pomelo")
        #expect(model.isSaved)
    }

    @Test func anotherLoadKeepsUnsavedText() async {
        let model = NotesModel(service: MockNoteService(text: "Pomelo"))
        await model.load()
        model.text = "Pomelo, peeled"
        await model.load()
        #expect(model.text == "Pomelo, peeled")
    }

    @Test func failedLoadShowsAMessageAndSavesNothing() async {
        let failure = NoteError.loadFailed(CocoaError(.fileReadCorruptFile))
        let service = MockNoteService(text: "Pomelo", failure: failure)
        let model = NotesModel(service: service)
        await model.load()
        #expect(model.errorMessage != nil)
        model.text = "Peel"
        await model.save()
        #expect(await service.text == "Pomelo")
    }

    @Test func failedSaveKeepsTheEdit() async {
        let failure = NoteError.saveFailed(CocoaError(.fileWriteOutOfSpace))
        let model = NotesModel(service: MockNoteService(failure: failure))
        await model.load()
        model.text = "Pomelo"
        await model.save()
        #expect(model.errorMessage != nil)
        #expect(!model.isSaved)
    }
}

@Test(arguments: [
    ("", 0),
    ("  ", 0),
    ("Pomelos are the largest citrus fruit.", 6),
    ("one, two... three!", 3),
])
func wordCount(text: String, words: Int) {
    #expect(WordCount.of(text) == words)
}
