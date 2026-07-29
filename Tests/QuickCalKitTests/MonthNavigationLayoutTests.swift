import Foundation
import Testing
import QuickCalKit

@Suite
struct MonthNavigationLayoutTests {
    @Test(arguments: [
        "September 2026",
        "сентябрь 2026",
    ])
    func compactHeaderKeepsLongMonthTitlesCenteredAndClearOfControls(
        title: String
    ) {
        let compactContentWidth: CGFloat = 310 - (2 * 16)
        let rightControlsWidth: CGFloat = 30 + 2 + 32
        let titleFrame = MonthNavigationLayout.titleFrame(
            in: compactContentWidth
        )

        #expect(
            titleFrame.midX == compactContentWidth / 2,
            "The \(title) title must remain visually centered."
        )
        #expect(
            titleFrame.minX >= rightControlsWidth,
            "The \(title) title must clear the mirrored leading reserve."
        )
        #expect(
            titleFrame.maxX <= compactContentWidth - rightControlsWidth,
            "The \(title) title must not overlap Today and Next."
        )
        #expect(MonthNavigationLayout.minimumTitleScale >= 0.8)
        #expect(MonthNavigationLayout.minimumTitleScale <= 1)
    }
}
