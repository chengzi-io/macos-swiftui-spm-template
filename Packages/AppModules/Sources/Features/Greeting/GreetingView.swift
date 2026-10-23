import SwiftUI

public struct GreetingView: View {
    @Bindable private var model: GreetingModel

    public init(model: GreetingModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField(text: $model.name) {
                Text("Name", bundle: .module)
            }
            .accessibilityIdentifier("greeting.name")
            .onSubmit { model.greet() }
            Button {
                model.greet()
            } label: {
                Text("Greet", bundle: .module)
            }
            .accessibilityIdentifier("greeting.greet")
            .keyboardShortcut(.defaultAction)
            if let greeting = model.greeting {
                Text(greeting)
                    .font(.title)
                    .accessibilityIdentifier("greeting.result")
            }
        }
        .padding(32)
        .frame(minWidth: 360, minHeight: 200)
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
    GreetingView(model: GreetingModel())
}
