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
        let offset = min(max(calendar.firstWeekday - 1, 0), 6)
        return Array(symbols[offset...]) + Array(symbols[..<offset])
    }

    public var weeks: [CalendarWeek] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: start),
            let lastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
            let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
            let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastDay)
        else {
            return []
        }

        let displayed = calendar.dateComponents([.year, .month], from: start)
        var result: [CalendarWeek] = []
        var weekStart = firstWeek.start

        while weekStart < lastWeek.end {
            let days = (0..<7).compactMap { offset -> CalendarDay? in
                guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
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
                    weekOfYear: calendar.component(.weekOfYear, from: weekStart),
                    days: days
                ))
            }

            guard
                let next = calendar.date(byAdding: .day, value: 7, to: weekStart),
                next > weekStart
            else {
                break
            }
            weekStart = next
        }

        return result
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
