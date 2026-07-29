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

        let hasSelectedPrevious = index > week.startIndex
            && selectedDates.contains(week[index - 1])
        let hasSelectedNext = index < week.index(before: week.endIndex)
            && selectedDates.contains(week[index + 1])

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
}
