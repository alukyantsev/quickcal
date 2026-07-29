import Foundation
import XCTest
@testable import QuickCalKit

final class CalendarMonthTests: XCTestCase {
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

    func testJuly2026UsesFiveCompleteMondayFirstWeeks() throws {
        let calendar = calendar()
        let month = try XCTUnwrap(CalendarMonth(
            containing: date(2026, 7, 15, calendar: calendar),
            calendar: calendar
        ))

        XCTAssertEqual(month.weeks.count, 5)
        XCTAssertEqual(
            month.weeks.first?.startDate,
            date(2026, 6, 29, calendar: calendar)
        )
        XCTAssertEqual(
            month.weeks.last?.days.last?.date,
            date(2026, 8, 2, calendar: calendar)
        )
        XCTAssertEqual(month.weeks.flatMap(\.days).count, 35)
    }

    func testLeapFebruaryContainsFebruary29() throws {
        let calendar = calendar()
        let month = try XCTUnwrap(CalendarMonth(
            containing: date(2028, 2, 12, calendar: calendar),
            calendar: calendar
        ))

        let displayedNumbers = month.weeks
            .flatMap(\.days)
            .filter(\.isInDisplayedMonth)
            .map(\.number)

        XCTAssertEqual(displayedNumbers, Array(1...29))
    }

    func testWeekdaySymbolsFollowFirstWeekday() throws {
        let mondayMonth = try XCTUnwrap(CalendarMonth(
            containing: Date(timeIntervalSince1970: 0),
            calendar: calendar(firstWeekday: 2)
        ))
        let sundayMonth = try XCTUnwrap(CalendarMonth(
            containing: Date(timeIntervalSince1970: 0),
            calendar: calendar(firstWeekday: 1)
        ))

        XCTAssertEqual(mondayMonth.weekdaySymbols.first, "Mon")
        XCTAssertEqual(sundayMonth.weekdaySymbols.first, "Sun")
    }

    func testShiftAcrossYearBoundary() throws {
        let calendar = calendar()
        let december = try XCTUnwrap(CalendarMonth(
            containing: date(2026, 12, 20, calendar: calendar),
            calendar: calendar
        ))
        let january = try XCTUnwrap(december.shifted(by: 1))
        let components = calendar.dateComponents([.year, .month], from: january.start)

        XCTAssertEqual(components.year, 2027)
        XCTAssertEqual(components.month, 1)
    }

    func testTodayComparisonUsesCalendarDay() throws {
        let calendar = calendar()
        let month = try XCTUnwrap(CalendarMonth(
            containing: date(2026, 7, 15, calendar: calendar),
            calendar: calendar
        ))
        let day = try XCTUnwrap(
            month.weeks.flatMap(\.days).first { $0.number == 29 && $0.isInDisplayedMonth }
        )

        XCTAssertTrue(month.isToday(
            day,
            relativeTo: date(2026, 7, 29, calendar: calendar)
        ))
        XCTAssertFalse(month.isToday(
            day,
            relativeTo: date(2026, 7, 30, calendar: calendar)
        ))
    }

    func testWeekNumbersBelongToEachRenderedRow() throws {
        let calendar = calendar()
        let month = try XCTUnwrap(CalendarMonth(
            containing: date(2026, 7, 15, calendar: calendar),
            calendar: calendar
        ))

        XCTAssertEqual(month.weeks.map(\.weekOfYear), [27, 28, 29, 30, 31])
    }
}
