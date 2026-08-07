import Foundation

public struct CalendarDay: Identifiable, Equatable, Sendable {
    public let date: Date
    public let number: Int
    public let isInDisplayedMonth: Bool

    public var id: Date { date }
}

public struct CalendarWeek: Identifiable, Equatable, Sendable {
    public let startDate: Date
    public let weekOfYear: Int
    public let days: [CalendarDay]

    public var id: Date { startDate }
}

public struct CalendarMonth: Sendable {
    public let start: Date
    public let calendar: Calendar

    public init?(containing date: Date, calendar: Calendar = .autoupdatingCurrent) {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return nil
        }
        self.start = interval.start
        self.calendar = calendar
    }

    public var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        guard symbols.count == 7 else {
            return symbols
        }
        return Array(symbols[1...]) + Array(symbols[..<1])
    }

    public var weeks: [CalendarWeek] {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2

        guard
            let monthInterval = calendar.dateInterval(of: .month, for: start),
            let lastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
            let firstWeek = weekCalendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
            let lastWeek = weekCalendar.dateInterval(of: .weekOfYear, for: lastDay),
            let firstSupplementaryWeek = weekCalendar.date(byAdding: .day, value: -7, to: firstWeek.start),
            let lastSupplementaryWeekEnd = weekCalendar.date(byAdding: .day, value: 7, to: lastWeek.end)
        else {
            return []
        }

        let displayed = calendar.dateComponents([.year, .month], from: start)
        var result: [CalendarWeek] = []
        var weekStart = firstSupplementaryWeek

        while weekStart < lastSupplementaryWeekEnd {
            let days = (0..<7).compactMap { offset -> CalendarDay? in
                guard let date = weekCalendar.date(byAdding: .day, value: offset, to: weekStart) else {
                    return nil
                }
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                return CalendarDay(
                    date: date,
                    number: components.day ?? 0,
                    isInDisplayedMonth: components.year == displayed.year
                        && components.month == displayed.month
                )
            }

            if days.count == 7 {
                result.append(CalendarWeek(
                    startDate: weekStart,
                    weekOfYear: weekCalendar.component(.weekOfYear, from: weekStart),
                    days: days
                ))
            }

            guard
                let next = weekCalendar.date(byAdding: .day, value: 7, to: weekStart),
                next > weekStart
            else {
                break
            }
            weekStart = next
        }

        return result
    }

    public var displayedYears: Set<Int> {
        Set(weeks.flatMap(\.days).compactMap {
            calendar.dateComponents([.year], from: $0.date).year
        })
    }

    public func shifted(by monthOffset: Int) -> CalendarMonth? {
        guard let date = calendar.date(byAdding: .month, value: monthOffset, to: start) else {
            return nil
        }
        return CalendarMonth(containing: date, calendar: calendar)
    }

    public func isToday(
        _ day: CalendarDay,
        relativeTo referenceDate: Date = Date()
    ) -> Bool {
        calendar.isDate(day.date, inSameDayAs: referenceDate)
    }
}
