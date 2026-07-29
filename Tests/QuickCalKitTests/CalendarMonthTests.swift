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
    func july2026UsesFiveCompleteMondayFirstWeeks() throws {
        let calendar = calendar()
        let month = try #require(CalendarMonth(
            containing: date(2026, 7, 15, calendar: calendar),
            calendar: calendar
        ))

        #expect(month.weeks.count == 5)
        #expect(month.weeks.first?.startDate == date(2026, 6, 29, calendar: calendar))
        #expect(month.weeks.last?.days.last?.date == date(2026, 8, 2, calendar: calendar))
        #expect(month.weeks.flatMap(\.days).count == 35)
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
    func weekdaySymbolsFollowFirstWeekday() throws {
        let mondayMonth = try #require(CalendarMonth(
            containing: Date(timeIntervalSince1970: 0),
            calendar: calendar(firstWeekday: 2)
        ))
        let sundayMonth = try #require(CalendarMonth(
            containing: Date(timeIntervalSince1970: 0),
            calendar: calendar(firstWeekday: 1)
        ))

        #expect(mondayMonth.weekdaySymbols.first == "Mon")
        #expect(sundayMonth.weekdaySymbols.first == "Sun")
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

        #expect(month.weeks.map(\.weekOfYear) == [27, 28, 29, 30, 31])
    }
}
