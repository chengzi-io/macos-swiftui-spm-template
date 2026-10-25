import Notes
import SwiftUI

public struct NotesView: View {
    @Bindable private var model: NotesModel

    public init(model: NotesModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $model.text)
                .font(.body)
                .accessibilityIdentifier("notes.text")
            Divider()
            HStack {
                Text("\(model.wordCount) words", bundle: .module)
                Spacer()
                Group {
                    if model.isSaved {
                        Text("Saved", bundle: .module)
                    } else {
                        Text("Edited", bundle: .module)
                    }
                }
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("notes.status")
                Button {
                    Task { await model.save() }
                } label: {
                    Text("Save", bundle: .module)
                }
                .keyboardShortcut("s")
                .disabled(model.isSaved || model.isSaving)
                .accessibilityIdentifier("notes.save")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 360, minHeight: 240)
        .task { await model.load() }
        .alert(
            Text("Something went wrong", bundle: .module),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

#Preview {
    NotesView(model: NotesModel(service: MockNoteService(text: "Pomelos are the largest citrus fruit.")))
}
