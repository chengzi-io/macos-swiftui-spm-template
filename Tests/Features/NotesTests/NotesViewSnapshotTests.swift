import AppKit
import Notes
import SnapshotSupport
import SnapshotTesting
import Testing

@testable import NotesFeature

@MainActor
@Suite(.snapshots(record: recording))
struct NotesViewSnapshotTests {
    @Test func saved() async throws {
        let model = await loadedModel()
        assertSnapshot(of: try render(NotesView(model: model)), as: .image(perceptualPrecision: 0.98))
    }

    @Test func edited() async throws {
        let model = await editedModel()
        assertSnapshot(of: try render(NotesView(model: model)), as: .image(perceptualPrecision: 0.98))
    }

    @Test func editedDark() async throws {
        let model = await editedModel()
        assertSnapshot(
            of: try render(NotesView(model: model), appearance: .darkAqua),
            as: .image(perceptualPrecision: 0.98)
        )
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
