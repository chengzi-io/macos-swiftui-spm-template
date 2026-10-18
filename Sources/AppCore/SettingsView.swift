import SwiftUI

enum SettingsKey {
    static let defaultName = "defaultName"
}

public struct SettingsView: View {
    @AppStorage(SettingsKey.defaultName) private var defaultName = ""

    public init() {}

    public var body: some View {
        Form {
            TextField(text: $defaultName) {
                Text("Default name", bundle: .module)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

#Preview {
    SettingsView()
}
