import Foundation
import Notes
import Testing

@testable import NotesFeature

@MainActor
struct NotesModelTests {
    @Test func loadShowsTheSavedNote() async {
        let model = NotesModel(service: MockNoteService(text: "Grapefruit"))
        await model.load()
        #expect(model.text == "Grapefruit")
        #expect(model.isSaved)
    }

    @Test func saveStoresTheText() async {
        let service = MockNoteService()
        let model = NotesModel(service: service)
        await model.load()
        model.text = "Grapefruit"
        #expect(!model.isSaved)
        await model.save()
        #expect(await service.text == "Grapefruit")
        #expect(model.isSaved)
    }

    @Test func anotherLoadKeepsUnsavedText() async {
        let model = NotesModel(service: MockNoteService(text: "Grapefruit"))
        await model.load()
        model.text = "Grapefruit, peeled"
        await model.load()
        #expect(model.text == "Grapefruit, peeled")
    }

    @Test func failedLoadShowsAMessageAndSavesNothing() async {
        let failure = NoteError.loadFailed(CocoaError(.fileReadCorruptFile))
        let service = MockNoteService(text: "Grapefruit", failure: failure)
        let model = NotesModel(service: service)
        await model.load()
        #expect(model.errorMessage != nil)
        model.text = "Peel"
        await model.save()
        #expect(await service.text == "Grapefruit")
    }

    @Test func failedSaveKeepsTheEdit() async {
        let failure = NoteError.saveFailed(CocoaError(.fileWriteOutOfSpace))
        let model = NotesModel(service: MockNoteService(failure: failure))
        await model.load()
        model.text = "Grapefruit"
        await model.save()
        #expect(model.errorMessage != nil)
        #expect(!model.isSaved)
    }
}

@Test(arguments: [
    ("", 0),
    ("  ", 0),
    ("Grapefruits are a large citrus fruit.", 6),
    ("one, two... three!", 3),
])
func wordCount(text: String, words: Int) {
    #expect(WordCount.of(text) == words)
}
