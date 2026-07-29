import Foundation

public struct CalendarDate: Codable, Hashable, Sendable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard Self.isValid(year: year, month: month, day: day) else {
            return nil
        }

        self.year = year
        self.month = month
        self.day = day
    }

    public init?(
        date: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        let calendar = Self.gregorianCalendar(timeZone: timeZone)
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return nil
        }

        self.init(year: year, month: month, day: day)
    }

    public func date(in timeZone: TimeZone = .autoupdatingCurrent) -> Date? {
        Self.gregorianCalendar(timeZone: timeZone).date(from: DateComponents(
            timeZone: timeZone,
            year: year,
            month: month,
            day: day
        ))
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let year = try container.decode(Int.self, forKey: .year)
        let month = try container.decode(Int.self, forKey: .month)
        let day = try container.decode(Int.self, forKey: .day)

        guard let date = Self(year: year, month: month, day: day) else {
            throw DecodingError.dataCorruptedError(
                forKey: .day,
                in: container,
                debugDescription: "Invalid Gregorian calendar date."
            )
        }

        self = date
    }

    private static func isValid(year: Int, month: Int, day: Int) -> Bool {
        guard (1...9999).contains(year) else {
            return false
        }

        let calendar = gregorianCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
        let components = DateComponents(year: year, month: month, day: day)

        guard let date = calendar.date(from: components) else {
            return false
        }

        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        return resolved.year == year
            && resolved.month == month
            && resolved.day == day
    }

    private static func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}
