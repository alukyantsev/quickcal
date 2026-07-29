import Foundation

public enum RussianWorkdayCode: Sendable, Equatable {
    case working
    case dayOff
    case shortened
    case holiday

    public var isNonWorking: Bool {
        switch self {
        case .working, .shortened:
            false
        case .dayOff, .holiday:
            true
        }
    }

    fileprivate init?(asciiByte: UInt8) {
        switch asciiByte {
        case 48:
            self = .working
        case 49:
            self = .dayOff
        case 50:
            self = .shortened
        case 56:
            self = .holiday
        default:
            return nil
        }
    }
}

public enum WorkdayStatus: Sendable, Equatable {
    case working
    case nonWorking
}

public struct RussianWorkCalendar: Sendable, Equatable {
    public enum ParseError: Error, Equatable, Sendable {
        case invalidYear(Int)
        case invalidLength(expected: Int, actual: Int)
        case invalidCode(byte: UInt8, index: Int)
    }

    public let year: Int
    private let codes: [RussianWorkdayCode]

    public init(year: Int, rawData: Data) throws {
        guard (1...9999).contains(year) else {
            throw ParseError.invalidYear(year)
        }

        let expectedCount = Self.isLeapYear(year) ? 366 : 365
        guard rawData.count == expectedCount else {
            throw ParseError.invalidLength(
                expected: expectedCount,
                actual: rawData.count
            )
        }

        var parsedCodes: [RussianWorkdayCode] = []
        parsedCodes.reserveCapacity(expectedCount)

        for (index, byte) in rawData.enumerated() {
            guard let code = RussianWorkdayCode(asciiByte: byte) else {
                throw ParseError.invalidCode(byte: byte, index: index)
            }
            parsedCodes.append(code)
        }

        self.year = year
        self.codes = parsedCodes
    }

    public func code(month: Int, day: Int) -> RussianWorkdayCode? {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!

        guard let date = gregorian.date(from: DateComponents(
            timeZone: gregorian.timeZone,
            year: year,
            month: month,
            day: day
        )) else {
            return nil
        }

        let components = gregorian.dateComponents(
            [.year, .month, .day],
            from: date
        )
        guard
            components.year == year,
            components.month == month,
            components.day == day,
            let ordinal = gregorian.ordinality(
                of: .day,
                in: .year,
                for: date
            )
        else {
            return nil
        }

        let index = ordinal - 1
        guard codes.indices.contains(index) else {
            return nil
        }
        return codes[index]
    }

    public func status(
        for date: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> WorkdayStatus? {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let components = gregorian.dateComponents(
            [.year, .month, .day],
            from: date
        )

        guard
            components.year == year,
            let month = components.month,
            let day = components.day,
            let code = code(month: month, day: day)
        else {
            return nil
        }

        return code.isNonWorking ? .nonWorking : .working
    }

    private static func isLeapYear(_ year: Int) -> Bool {
        year.isMultiple(of: 4)
            && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
    }
}
