import Foundation

public enum SelectionSegment: Equatable, Sendable {
    case none
    case isolated
    case leading
    case middle
    case trailing

    public static func forDay(
        at index: Int,
        in week: [CalendarDate],
        selectedDates: Set<CalendarDate>
    ) -> SelectionSegment {
        guard week.indices.contains(index), selectedDates.contains(week[index]) else {
            return .none
        }

        let hasSelectedPrevious = adjacent(to: week[index], by: -1)
            .map { selectedDates.contains($0) } ?? false
        let hasSelectedNext = adjacent(to: week[index], by: 1)
            .map { selectedDates.contains($0) } ?? false

        switch (hasSelectedPrevious, hasSelectedNext) {
        case (false, false):
            return .isolated
        case (false, true):
            return .leading
        case (true, true):
            return .middle
        case (true, false):
            return .trailing
        }
    }

    private static func adjacent(
        to date: CalendarDate,
        by dayOffset: Int
    ) -> CalendarDate? {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard
            let source = date.date(in: timeZone),
            let adjacent = calendar.date(byAdding: .day, value: dayOffset, to: source)
        else {
            return nil
        }
        return CalendarDate(date: adjacent, timeZone: timeZone)
    }
}
