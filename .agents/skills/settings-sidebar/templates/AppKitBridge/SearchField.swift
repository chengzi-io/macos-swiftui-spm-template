import AppKit
import SwiftUI

/// AppKit's search field, for a field outside `.searchable`. It takes ⌘F from anywhere in
/// its window, as System Settings' field does.
public struct SearchField: NSViewRepresentable {
    @Binding private var text: String

    public init(text: Binding<String>) {
        _text = text
    }

    public func makeNSView(context: Context) -> NSSearchField {
        let field = FindShortcutSearchField()
        field.sendsSearchStringImmediately = true
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchChanged(_:))
        return field
    }

    public func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    public final class Coordinator: NSObject {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func searchChanged(_ field: NSSearchField) {
            text.wrappedValue = field.stringValue
        }
    }
}

private final class FindShortcutSearchField: NSSearchField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
            event.charactersIgnoringModifiers == "f"
        else { return super.performKeyEquivalent(with: event) }
        return window?.makeFirstResponder(self) ?? false
    }
}

#Preview {
    SearchField(text: .constant(""))
        .padding()
}
