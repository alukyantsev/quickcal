import Testing
import QuickCalKit

@Suite
struct SelectionSegmentTests {
    @Test
    func contiguousSelectionUsesLeadingMiddleAndTrailingSegments() throws {
        let week = try weekDates(startingAt: 1)
        let selectedDates: Set<CalendarDate> = [week[1], week[2], week[3], week[5]]

        #expect(SelectionSegment.forDay(
            at: 0,
            in: week,
            selectedDates: selectedDates
        ) == .none)
        #expect(SelectionSegment.forDay(
            at: 1,
            in: week,
            selectedDates: selectedDates
        ) == .leading)
        #expect(SelectionSegment.forDay(
            at: 2,
            in: week,
            selectedDates: selectedDates
        ) == .middle)
        #expect(SelectionSegment.forDay(
            at: 3,
            in: week,
            selectedDates: selectedDates
        ) == .trailing)
        #expect(SelectionSegment.forDay(
            at: 5,
            in: week,
            selectedDates: selectedDates
        ) == .isolated)
    }

    @Test
    func adjacentDatesAcrossAWeekBoundaryConnectSelectionSegments() throws {
        let firstWeek = try weekDates(startingAt: 1)
        let secondWeek = try weekDates(startingAt: 8)
        let selectedDates: Set<CalendarDate> = [
            firstWeek[6],
            secondWeek[0],
        ]

        #expect(SelectionSegment.forDay(
            at: 6,
            in: firstWeek,
            selectedDates: selectedDates
        ) == .leading)
        #expect(SelectionSegment.forDay(
            at: 0,
            in: secondWeek,
            selectedDates: selectedDates
        ) == .trailing)
    }

    @Test
    func adjacentDatesAcrossAMonthBoundaryConnectSelectionSegments() throws {
        let july31 = try #require(CalendarDate(year: 2026, month: 7, day: 31))
        let august1 = try #require(CalendarDate(year: 2026, month: 8, day: 1))
        let week = [
            try #require(CalendarDate(year: 2026, month: 7, day: 27)),
            try #require(CalendarDate(year: 2026, month: 7, day: 28)),
            try #require(CalendarDate(year: 2026, month: 7, day: 29)),
            try #require(CalendarDate(year: 2026, month: 7, day: 30)),
            july31,
            august1,
            try #require(CalendarDate(year: 2026, month: 8, day: 2)),
        ]
        let selectedDates: Set<CalendarDate> = [july31, august1]

        #expect(SelectionSegment.forDay(
            at: 4,
            in: week,
            selectedDates: selectedDates
        ) == .leading)
        #expect(SelectionSegment.forDay(
            at: 5,
            in: week,
            selectedDates: selectedDates
        ) == .trailing)
    }

    @Test
    func outOfBoundsIndexHasNoSelectionSegment() throws {
        let week = try weekDates(startingAt: 1)

        #expect(SelectionSegment.forDay(
            at: -1,
            in: week,
            selectedDates: Set(week)
        ) == .none)
        #expect(SelectionSegment.forDay(
            at: week.count,
            in: week,
            selectedDates: Set(week)
        ) == .none)
    }

    private func weekDates(startingAt day: Int) throws -> [CalendarDate] {
        try (day..<(day + 7)).map {
            try #require(CalendarDate(year: 2026, month: 7, day: $0))
        }
    }
}
