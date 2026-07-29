import AppKit
import Testing
@testable import QuickCal

@Suite(.serialized)
struct PopoverAppearanceTests {
    @MainActor
    @Test
    func preparedPopoverUsesTheRequestedSystemAppearance() throws {
        let popover = NSPopover()
        let darkAppearance = try #require(
            NSAppearance(named: .darkAqua)
        )

        PopoverAppearanceSynchronizer.apply(
            darkAppearance,
            to: popover
        )

        #expect(popover.appearance?.name == .darkAqua)
        #expect(popover.effectiveAppearance.name == .darkAqua)
    }
}
