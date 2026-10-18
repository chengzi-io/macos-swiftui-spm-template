import SwiftUI

/// Menu item for the updater. Lives here, not next to Sparkle, so its title is
/// localized from this package's string catalog.
public struct CheckForUpdatesButton: View {
    private let canCheck: Bool
    private let action: () -> Void

    public init(canCheck: Bool, action: @escaping () -> Void) {
        self.canCheck = canCheck
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text("Check for Updates…", bundle: .module)
        }
        .disabled(!canCheck)
    }
}
