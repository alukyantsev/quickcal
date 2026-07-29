import Foundation
import Testing
import QuickCalKit

@Suite
struct RussianWorkCalendarParserTests {
    @Test
    func parsesEverySupportedCodeForANonLeapYear() throws {
        var bytes = [UInt8](repeating: Character("0").asciiValue!, count: 365)
        bytes[0] = Character("1").asciiValue!
        bytes[1] = Character("2").asciiValue!
        bytes[2] = Character("8").asciiValue!

        let calendar = try RussianWorkCalendar(
            year: 2025,
            rawData: Data(bytes)
        )

        #expect(calendar.code(month: 1, day: 1) == .dayOff)
        #expect(calendar.code(month: 1, day: 2) == .shortened)
        #expect(calendar.code(month: 1, day: 3) == .holiday)
        #expect(calendar.code(month: 12, day: 31) == .working)
    }

    @Test
    func mapsLeapDayToTheSixtiethResponseByte() throws {
        var bytes = [UInt8](repeating: Character("0").asciiValue!, count: 366)
        bytes[59] = Character("8").asciiValue!
        bytes[60] = Character("1").asciiValue!

        let calendar = try RussianWorkCalendar(
            year: 2028,
            rawData: Data(bytes)
        )

        #expect(calendar.code(month: 2, day: 29) == .holiday)
        #expect(calendar.code(month: 3, day: 1) == .dayOff)
    }

    @Test(arguments: [
        (2025, 364),
        (2025, 366),
        (2028, 365),
        (2028, 367),
    ])
    func rejectsAnythingButTheExactGregorianDayCount(
        year: Int,
        byteCount: Int
    ) {
        let rawData = Data(
            repeating: Character("0").asciiValue!,
            count: byteCount
        )

        #expect(throws: RussianWorkCalendar.ParseError.invalidLength(
            expected: year == 2028 ? 366 : 365,
            actual: byteCount
        )) {
            try RussianWorkCalendar(year: year, rawData: rawData)
        }
    }

    @Test(arguments: [
        Character("3").asciiValue!,
        Character("9").asciiValue!,
        Character("\n").asciiValue!,
    ])
    func rejectsUnsupportedOrServiceResponseBytes(_ byte: UInt8) {
        var rawData = Data(
            repeating: Character("0").asciiValue!,
            count: 365
        )
        rawData[100] = byte

        #expect(throws: RussianWorkCalendar.ParseError.invalidCode(
            byte: byte,
            index: 100
        )) {
            try RussianWorkCalendar(year: 2025, rawData: rawData)
        }
    }

    @Test
    func rejectsYearsOutsideFoundationGregorianRange() {
        #expect(throws: RussianWorkCalendar.ParseError.invalidYear(0)) {
            try RussianWorkCalendar(year: 0, rawData: Data())
        }
    }

    @Test
    func returnsNilForDatesOutsideTheCalendarYearOrInvalidDates() throws {
        let calendar = try RussianWorkCalendar(
            year: 2025,
            rawData: Data(
                repeating: Character("0").asciiValue!,
                count: 365
            )
        )

        #expect(calendar.code(month: 2, day: 29) == nil)
        #expect(calendar.code(month: 13, day: 1) == nil)

        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = gregorian.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 1
        ))!
        #expect(calendar.status(for: date, timeZone: gregorian.timeZone) == nil)
    }
}
