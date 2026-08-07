import Foundation

public struct VacationRange: Equatable, Sendable {
    public let start: CalendarDate
    public let end: CalendarDate

    public init(start: CalendarDate, end: CalendarDate) {
        self.start = start
        self.end = end
    }

    public var isSingleDay: Bool {
        start == end
    }
}

public enum VacationCountdown: Equatable, Sendable {
    case future(range: VacationRange, daysUntilStart: Int)
    case inProgress(range: VacationRange, daysRemaining: Int)
    case finalDay(VacationRange)
    case today(VacationRange)

    public static func currentOrUpcoming(
        from selectedDates: Set<CalendarDate>,
        now: Date = Date(),
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> VacationCountdown? {
        guard let today = CalendarDate(date: now, timeZone: timeZone) else {
            return nil
        }

        let calendar = VacationCalendar.gregorian(timeZone: timeZone)
        let ranges = vacationRanges(from: selectedDates, calendar: calendar)

        for range in ranges {
            if range.end < today {
                continue
            }

            if range.start > today {
                return .future(
                    range: range,
                    daysUntilStart: days(from: today, to: range.start, calendar: calendar)
                )
            }

            if range.isSingleDay {
                return .today(range)
            }

            let daysRemaining = days(from: today, to: range.end, calendar: calendar)
            return daysRemaining == 0
                ? .finalDay(range)
                : .inProgress(range: range, daysRemaining: daysRemaining)
        }

        return nil
    }

    private static func vacationRanges(
        from selectedDates: Set<CalendarDate>,
        calendar: Calendar
    ) -> [VacationRange] {
        let dates = selectedDates.sorted()
        guard let first = dates.first else {
            return []
        }

        var ranges: [VacationRange] = []
        var start = first
        var previous = first

        for date in dates.dropFirst() {
            if days(from: previous, to: date, calendar: calendar) == 1 {
                previous = date
                continue
            }

            ranges.append(VacationRange(start: start, end: previous))
            start = date
            previous = date
        }

        ranges.append(VacationRange(start: start, end: previous))
        return ranges
    }

    private static func days(
        from start: CalendarDate,
        to end: CalendarDate,
        calendar: Calendar
    ) -> Int {
        guard
            let startDate = start.date(in: calendar.timeZone),
            let endDate = end.date(in: calendar.timeZone)
        else {
            return 0
        }

        return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

}

public enum VacationPresentation {
    public static func string(
        for countdown: VacationCountdown,
        timeZone: TimeZone = .autoupdatingCurrent,
        localization: QuickCalLocalization = .current
    ) -> String {
        switch countdown {
        case let .future(range, daysUntilStart):
            return localization.format(
                futureKey(for: daysUntilStart, language: localization.languageIdentifier),
                daysUntilStart,
                rangeText(range, timeZone: timeZone, localization: localization)
            )
        case let .inProgress(range, daysRemaining):
            return localization.format(
                remainingKey(for: daysRemaining, language: localization.languageIdentifier),
                daysRemaining,
                dayText(range.end, timeZone: timeZone, localization: localization)
            )
        case let .finalDay(range):
            return localization.format(
                .vacationFinalDay,
                dayText(range.end, timeZone: timeZone, localization: localization)
            )
        case let .today(range):
            return localization.format(
                .vacationToday,
                rangeText(range, timeZone: timeZone, localization: localization)
            )
        }
    }

    private static func futureKey(for count: Int, language: String) -> QuickCalLocalization.Key {
        pluralKey(
            count: count,
            language: language,
            one: .vacationFutureOne,
            few: .vacationFutureFew,
            many: .vacationFutureMany
        )
    }

    private static func remainingKey(for count: Int, language: String) -> QuickCalLocalization.Key {
        pluralKey(
            count: count,
            language: language,
            one: .vacationRemainingOne,
            few: .vacationRemainingFew,
            many: .vacationRemainingMany
        )
    }

    private static func pluralKey(
        count: Int,
        language: String,
        one: QuickCalLocalization.Key,
        few: QuickCalLocalization.Key,
        many: QuickCalLocalization.Key
    ) -> QuickCalLocalization.Key {
        guard language == "ru" else {
            return count == 1 ? one : many
        }

        let modulo100 = count % 100
        let modulo10 = count % 10
        if modulo100 == 11 || modulo100 == 12 || modulo100 == 13 || modulo100 == 14 {
            return many
        }
        if modulo10 == 1 {
            return one
        }
        if (2...4).contains(modulo10) {
            return few
        }
        return many
    }

    private static func rangeText(
        _ range: VacationRange,
        timeZone: TimeZone,
        localization: QuickCalLocalization
    ) -> String {
        guard !range.isSingleDay else {
            return dayText(range.start, timeZone: timeZone, localization: localization)
        }

        if range.start.year == range.end.year, range.start.month == range.end.month {
            let month = monthText(range.start, timeZone: timeZone, localization: localization)
            if localization.languageIdentifier == "ru" {
                return "\(range.start.day)–\(range.end.day) \(month)"
            }
            return "\(month) \(range.start.day)–\(range.end.day)"
        }

        return "\(dayText(range.start, timeZone: timeZone, localization: localization)) – \(dayText(range.end, timeZone: timeZone, localization: localization))"
    }

    private static func dayText(
        _ date: CalendarDate,
        timeZone: TimeZone,
        localization: QuickCalLocalization
    ) -> String {
        guard let foundationDate = date.date(in: timeZone) else {
            return ""
        }

        return foundationDate.formatted(
            Date.FormatStyle(
                locale: localization.locale,
                calendar: VacationCalendar.gregorian(timeZone: timeZone),
                timeZone: timeZone
            )
            .day()
            .month(.wide)
        )
    }

    private static func monthText(
        _ date: CalendarDate,
        timeZone: TimeZone,
        localization: QuickCalLocalization
    ) -> String {
        guard localization.languageIdentifier == "ru" else {
            return standaloneMonthText(
                date,
                timeZone: timeZone,
                localization: localization
            )
        }

        let day = String(date.day)
        let formattedDate = dayText(
            date,
            timeZone: timeZone,
            localization: localization
        )
        guard formattedDate.hasPrefix(day) else {
            return formattedDate
        }
        return formattedDate.dropFirst(day.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func standaloneMonthText(
        _ date: CalendarDate,
        timeZone: TimeZone,
        localization: QuickCalLocalization
    ) -> String {
        guard let foundationDate = date.date(in: timeZone) else {
            return ""
        }

        return foundationDate.formatted(
            Date.FormatStyle(
                locale: localization.locale,
                calendar: VacationCalendar.gregorian(timeZone: timeZone),
                timeZone: timeZone
            )
            .month(.wide)
        )
    }
}

private enum VacationCalendar {
    static func gregorian(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
