import AppKit
import RenderSupport
import Testing

@testable import DemoFeature

@MainActor
struct DemoViewRenderTests {
    @Test func view() throws {
        try render(DemoView(model: DemoModel()))
    }

    @Test func viewDark() throws {
        try render(DemoView(model: DemoModel()), appearance: .darkAqua)
    }
}
