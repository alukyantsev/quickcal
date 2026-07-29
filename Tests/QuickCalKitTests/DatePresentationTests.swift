import Foundation
import Testing
@testable import QuickCalKit

@Suite
struct DatePresentationTests {
    private let date: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 7
        components.day = 29
        components.hour = 12
        return components.date!
    }()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test
    func russianFullDateAndMonthHaveNoYearSuffix() {
        let localization = QuickCalLocalization(
            preferredLanguages: ["ru-RU"],
            systemLocale: Locale(identifier: "ru_RU")
        )

        let fullDate = DatePresentation.fullDate(
            date,
            calendar: calendar,
            localization: localization
        )
        let month = DatePresentation.monthTitle(
            date,
            calendar: calendar,
            localization: localization
        )

        #expect(fullDate == "среда, 29 июля 2026")
        #expect(month == "июль 2026")
        #expect(!fullDate.contains(" г."))
        #expect(!fullDate.contains("года"))
        #expect(!month.contains(" г."))
        #expect(!month.contains("года"))
    }

    @Test
    func englishFullDateAndMonthUseEnglishOrdering() {
        let localization = QuickCalLocalization(
            preferredLanguages: ["en-US"],
            systemLocale: Locale(identifier: "en_US")
        )

        #expect(
            DatePresentation.fullDate(
                date,
                calendar: calendar,
                localization: localization
            ) == "Wednesday, July 29, 2026"
        )
        #expect(
            DatePresentation.monthTitle(
                date,
                calendar: calendar,
                localization: localization
            ) == "July 2026"
        )
    }

    @Test
    func englishFormattingPreservesBritishRegion() {
        let localization = QuickCalLocalization(
            preferredLanguages: ["en-GB"],
            systemLocale: Locale(identifier: "en_GB")
        )

        #expect(
            DatePresentation.fullDate(
                date,
                calendar: calendar,
                localization: localization
            ) == "Wednesday 29 July, 2026"
        )
    }
}
