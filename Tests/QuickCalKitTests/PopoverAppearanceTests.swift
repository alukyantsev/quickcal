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

    @MainActor
    @Test
    func darkThemeUsesDarkPopoverAppearance() {
        let popover = NSPopover()

        PopoverAppearanceSynchronizer.apply(
            theme: .colorDark,
            to: popover
        )

        #expect(popover.appearance?.name == .darkAqua)
        #expect(popover.effectiveAppearance.name == .darkAqua)
    }

    @MainActor
    @Test
    func lightThemeUsesLightPopoverAppearance() {
        let popover = NSPopover()

        PopoverAppearanceSynchronizer.apply(
            theme: .swissLight,
            to: popover
        )

        #expect(popover.appearance?.name == .aqua)
        #expect(popover.effectiveAppearance.name == .aqua)
    }
}
