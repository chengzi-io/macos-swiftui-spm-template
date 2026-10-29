import SwiftUI

public struct DemoView: View {
    private let model: DemoModel

    public init(model: DemoModel) {
        self.model = model
    }

    public var body: some View {
        Text("Demo", bundle: .module)
            .padding()
    }
}

#Preview {
    DemoView(model: DemoModel())
}
