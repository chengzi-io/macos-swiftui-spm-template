import AppKit
import Notes
import RenderSupport
import Testing

@testable import NotesFeature

@MainActor
struct NotesViewRenderTests {
    @Test func saved() async throws {
        let model = await loadedModel()
        try render(NotesView(model: model))
    }

    @Test func edited() async throws {
        let model = await editedModel()
        try render(NotesView(model: model))
    }

    @Test func editedDark() async throws {
        let model = await editedModel()
        try render(NotesView(model: model), appearance: .darkAqua)
    }

    private func loadedModel() async -> NotesModel {
        let model = NotesModel(service: MockNoteService(text: "Pomelos are the largest citrus fruit."))
        await model.load()
        return model
    }

    private func editedModel() async -> NotesModel {
        let model = await loadedModel()
        model.text += " Peel them first."
        return model
    }
}
