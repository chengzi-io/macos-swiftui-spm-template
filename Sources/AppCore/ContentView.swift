import SwiftUI

public struct ContentView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.defaultName) private var defaultName = ""

    public init() {}

    public var body: some View {
        @Bindable var model = model
        VStack(spacing: 16) {
            TextField(text: $model.name) {
                Text("Name", bundle: .module)
            }
            .onSubmit { model.greet() }
            Button {
                model.greet()
            } label: {
                Text("Greet", bundle: .module)
            }
            .keyboardShortcut(.defaultAction)
            if let greeting = model.greeting {
                Text(greeting).font(.title)
            }
        }
        .padding(32)
        .frame(minWidth: 360, minHeight: 200)
        .onAppear {
            if model.name.isEmpty { model.name = defaultName }
        }
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
    ContentView()
        .environment(AppModel())
}
