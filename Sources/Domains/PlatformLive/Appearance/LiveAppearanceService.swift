import AppKit
import Platform

/// Sets `NSApp.appearance`, which every window follows; nil follows the Mac.
@MainActor
public final class LiveAppearanceService: AppearanceService {
    public init() {}

    public func apply(_ appearance: Appearance) {
        NSApplication.shared.appearance = Self.appearanceName(for: appearance).flatMap(NSAppearance.init(named:))
    }

    static func appearanceName(for appearance: Appearance) -> NSAppearance.Name? {
        switch appearance {
        case .system: nil
        case .light: .aqua
        case .dark: .darkAqua
        }
    }
}
