import Foundation
import Testing
import QuickCalKit

@Suite
struct CalendarMonthTests {
    private func calendar(firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = firstWeekday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        ))!
    }

    @Test
    func july2026IncludesBoundaryWeeksAndSupplementaryWeeks() throws {
        let calendar = calendar()
        let month = try #require(CalendarMonth(
            containing: date(2026, 7, 15, calendar: calendar),
            calendar: calendar
        ))

        #expect(month.weeks.count == 7)
        #expect(month.weeks.first?.startDate == date(2026, 6, 22, calendar: calendar))
        #expect(month.weeks.last?.days.last?.date == date(2026, 8, 9, calendar: calendar))
        #expect(month.weeks.flatMap(\.days).count == 49)
    }

    @Test
    func leapFebruaryContainsFebruary29() throws {
        let calendar = calendar()
        let month = try #require(CalendarMonth(
            containing: date(2028, 2, 12, calendar: calendar),
            calendar: calendar
        ))

        let displayedNumbers = month.weeks
            .flatMap(\.days)
            .filter(\.isInDisplayedMonth)
            .map(\.number)

        #expect(displayedNumbers == Array(1...29))
    }

    @Test
    func weekdaySymbolsAndWeeksAlwaysStartOnMonday() throws {
        let sundayMonth = try #require(CalendarMonth(
            containing: date(2026, 7, 15, calendar: calendar(firstWeekday: 1)),
            calendar: calendar(firstWeekday: 1)
        ))

        #expect(sundayMonth.weekdaySymbols.first == "Mon")
        #expect(sundayMonth.weeks.allSatisfy {
            calendar(firstWeekday: 2).component(.weekday, from: $0.startDate) == 2
        })
    }

    @Test
    func shiftAcrossYearBoundary() throws {
        let calendar = calendar()
        let december = try #require(CalendarMonth(
            containing: date(2026, 12, 20, calendar: calendar),
            calendar: calendar
        ))
        let january = try #require(december.shifted(by: 1))
        let components = calendar.dateComponents([.year, .month], from: january.start)

        #expect(components.year == 2027)
        #expect(components.month == 1)
    }

    @Test
    func todayComparisonUsesCalendarDay() throws {
        let calendar = calendar()
        let month = try #require(CalendarMonth(
            containing: date(2026, 7, 15, calendar: calendar),
            calendar: calendar
        ))
        let day = try #require(
            month.weeks.flatMap(\.days).first { $0.number == 29 && $0.isInDisplayedMonth }
        )

        #expect(month.isToday(
            day,
            relativeTo: date(2026, 7, 29, calendar: calendar)
        ))
        #expect(!month.isToday(
            day,
            relativeTo: date(2026, 7, 30, calendar: calendar)
        ))
    }

    @Test
    func weekNumbersBelongToEachRenderedRow() throws {
        let calendar = calendar()
        let month = try #require(CalendarMonth(
            containing: date(2026, 7, 15, calendar: calendar),
            calendar: calendar
        ))

        #expect(month.weeks.map(\.weekOfYear) == [26, 27, 28, 29, 30, 31, 32])
    }

    @Test
    func decemberSupplementaryWeekIncludesFollowingYear() throws {
        let calendar = calendar()
        let month = try #require(CalendarMonth(
            containing: date(2026, 12, 15, calendar: calendar),
            calendar: calendar
        ))

        #expect(month.weeks.first?.startDate == date(2026, 11, 23, calendar: calendar))
        #expect(month.weeks.last?.days.last?.date == date(2027, 1, 10, calendar: calendar))
        #expect(month.displayedYears == [2026, 2027])
    }

    @Test
    func august2026KeepsSixBoundaryWeeksAndAddsTwoSupplementaryWeeks() throws {
        let calendar = calendar()
        let month = try #require(CalendarMonth(
            containing: date(2026, 8, 15, calendar: calendar),
            calendar: calendar
        ))

        #expect(month.weeks.count == 8)
        #expect(month.weeks.first?.startDate == date(2026, 7, 20, calendar: calendar))
        #expect(month.weeks.last?.days.last?.date == date(2026, 9, 13, calendar: calendar))
    }
}
