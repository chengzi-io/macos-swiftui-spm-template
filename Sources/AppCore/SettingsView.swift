import SwiftUI

enum SettingsKey {
    static let defaultName = "defaultName"
}

public struct SettingsView: View {
    @AppStorage(SettingsKey.defaultName) private var defaultName = ""
    private let automaticallyChecksForUpdates: Binding<Bool>?

    /// Pass nil where the app does not update itself (App Store builds).
    public init(automaticallyChecksForUpdates: Binding<Bool>?) {
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    public var body: some View {
        Form {
            TextField(text: $defaultName) {
                Text("Default name", bundle: .module)
            }
            if let automaticallyChecksForUpdates {
                Toggle(isOn: automaticallyChecksForUpdates) {
                    Text("Automatically check for updates", bundle: .module)
                }
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

#Preview {
    SettingsView(automaticallyChecksForUpdates: .constant(true))
}
