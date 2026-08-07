import Foundation
import Testing
@testable import QuickCalKit

@Suite
struct VacationCountdownTests {
    private let timeZone = TimeZone(identifier: "Europe/Moscow")!

    @Test
    func joinsConsecutiveDatesAcrossMonthsAndSeparatesGaps() throws {
        let countdown = VacationCountdown.currentOrUpcoming(
            from: dates("2026-07-31", "2026-08-01", "2026-08-03"),
            now: date("2026-07-20"),
            timeZone: timeZone
        )

        #expect(countdown == .future(
            range: VacationRange(start: try calendarDate("2026-07-31"), end: try calendarDate("2026-08-01")),
            daysUntilStart: 11
        ))
    }

    @Test
    func selectsCurrentVacationBeforeLaterFutureVacation() throws {
        let countdown = VacationCountdown.currentOrUpcoming(
            from: dates("2026-08-06", "2026-08-07", "2026-08-20"),
            now: date("2026-08-07"),
            timeZone: timeZone
        )

        #expect(countdown == .finalDay(
            VacationRange(start: try calendarDate("2026-08-06"), end: try calendarDate("2026-08-07"))
        ))
    }

    @Test
    func excludesTodayFromRemainingDaysDuringMultiDayVacation() throws {
        let countdown = VacationCountdown.currentOrUpcoming(
            from: dates("2026-08-06", "2026-08-07", "2026-08-08", "2026-08-09"),
            now: date("2026-08-07"),
            timeZone: timeZone
        )

        #expect(countdown == .inProgress(
            range: VacationRange(start: try calendarDate("2026-08-06"), end: try calendarDate("2026-08-09")),
            daysRemaining: 2
        ))
    }

    @Test
    func distinguishesOneDayVacationTodayFromFinalDay() throws {
        let countdown = VacationCountdown.currentOrUpcoming(
            from: dates("2026-08-07"),
            now: date("2026-08-07"),
            timeZone: timeZone
        )

        #expect(countdown == .today(VacationRange(
            start: try calendarDate("2026-08-07"),
            end: try calendarDate("2026-08-07")
        )))
    }

    @Test
    func omitsPastOnlySelection() {
        let countdown = VacationCountdown.currentOrUpcoming(
            from: dates("2026-08-01", "2026-08-02"),
            now: date("2026-08-07"),
            timeZone: timeZone
        )

        #expect(countdown == nil)
    }

    @Test
    func formatsEnglishAndRussianCountsAndRanges() throws {
        let future = VacationCountdown.future(
            range: VacationRange(start: try calendarDate("2026-07-31"), end: try calendarDate("2026-08-02")),
            daysUntilStart: 2
        )
        let active = VacationCountdown.inProgress(
            range: VacationRange(start: try calendarDate("2026-08-06"), end: try calendarDate("2026-08-09")),
            daysRemaining: 2
        )
        let russian = QuickCalLocalization(
            preferredLanguages: ["ru-RU"],
            systemLocale: Locale(identifier: "ru_RU")
        )
        let english = QuickCalLocalization(
            preferredLanguages: ["en-US"],
            systemLocale: Locale(identifier: "en_US")
        )

        #expect(VacationPresentation.string(for: future, timeZone: timeZone, localization: english) == "Vacation in 2 days · July 31 – August 2")
        #expect(VacationPresentation.string(for: future, timeZone: timeZone, localization: russian) == "Отпуск через 2 дня · 31 июля – 2 августа")
        #expect(VacationPresentation.string(for: active, timeZone: timeZone, localization: english) == "Vacation: 2 days remaining · until August 9")
        #expect(VacationPresentation.string(for: active, timeZone: timeZone, localization: russian) == "Отпуск: осталось 2 дня · до 9 августа")
        #expect(VacationPresentation.string(
            for: .today(VacationRange(
                start: try calendarDate("2026-08-07"),
                end: try calendarDate("2026-08-07")
            )),
            timeZone: timeZone,
            localization: russian
        ) == "Отпуск сегодня · 7 августа")
        #expect(VacationPresentation.string(
            for: .finalDay(VacationRange(
                start: try calendarDate("2026-08-06"),
                end: try calendarDate("2026-08-07")
            )),
            timeZone: timeZone,
            localization: english
        ) == "Last day of vacation · until August 7")
        #expect(VacationPresentation.string(
            for: .future(
                range: VacationRange(
                    start: try calendarDate("2026-08-06"),
                    end: try calendarDate("2026-08-09")
                ),
                daysUntilStart: 2
            ),
            timeZone: timeZone,
            localization: english
        ) == "Vacation in 2 days · August 6–9")
        #expect(VacationPresentation.string(
            for: .future(
                range: VacationRange(
                    start: try calendarDate("2026-08-06"),
                    end: try calendarDate("2026-08-09")
                ),
                daysUntilStart: 2
            ),
            timeZone: timeZone,
            localization: russian
        ) == "Отпуск через 2 дня · 6–9 августа")
    }

    @Test
    func usesRussianSingularFewAndManyFormsForCountdowns() throws {
        let range = VacationRange(
            start: try calendarDate("2026-08-10"),
            end: try calendarDate("2026-08-10")
        )
        let russian = QuickCalLocalization(
            preferredLanguages: ["ru-RU"],
            systemLocale: Locale(identifier: "ru_RU")
        )

        #expect(VacationPresentation.string(
            for: .future(range: range, daysUntilStart: 1),
            timeZone: timeZone,
            localization: russian
        ) == "Отпуск через 1 день · 10 августа")
        #expect(VacationPresentation.string(
            for: .future(range: range, daysUntilStart: 5),
            timeZone: timeZone,
            localization: russian
        ) == "Отпуск через 5 дней · 10 августа")
        #expect(VacationPresentation.string(
            for: .inProgress(range: range, daysRemaining: 1),
            timeZone: timeZone,
            localization: russian
        ) == "Отпуск: остался 1 день · до 10 августа")
        #expect(VacationPresentation.string(
            for: .inProgress(range: range, daysRemaining: 5),
            timeZone: timeZone,
            localization: russian
        ) == "Отпуск: осталось 5 дней · до 10 августа")
    }

    private func dates(_ values: String...) -> Set<CalendarDate> {
        Set(values.compactMap { try? calendarDate($0) })
    }

    private func calendarDate(_ value: String) throws -> CalendarDate {
        let components = value.split(separator: "-").compactMap { Int($0) }
        return try #require(CalendarDate(
            year: components[0], month: components[1], day: components[2]
        ))
    }

    private func date(_ value: String) -> Date {
        let components = value.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: components[0], month: components[1], day: components[2]
        ))!
    }
}
