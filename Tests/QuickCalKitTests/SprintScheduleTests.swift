import Foundation
import Testing
@testable import QuickCalKit

@Suite
@MainActor
struct SprintScheduleTests {
    @Test
    func fourteenDayScheduleUsesConfiguredStartAndNumberAcrossYearBoundary() throws {
        let calendar = calendar()
        let start = try #require(CalendarDate(year: 2026, month: 12, day: 29))
        let schedule = try #require(SprintSchedule(
            startDate: start,
            firstSprintNumber: 42,
            timeZone: calendar.timeZone
        ))

        #expect(schedule.sprint(for: date(2026, 12, 29, calendar: calendar))?.number == 42)
        #expect(schedule.sprint(for: date(2027, 1, 11, calendar: calendar))?.number == 42)
        #expect(schedule.sprint(for: date(2027, 1, 12, calendar: calendar))?.number == 43)
    }

    @Test
    func sprintNumbersIncludeEachSprintTouchedByThatWeek() throws {
        let calendar = calendar()
        let start = try #require(CalendarDate(year: 2026, month: 7, day: 8))
        let schedule = try #require(SprintSchedule(
            startDate: start,
            firstSprintNumber: 8,
            timeZone: calendar.timeZone
        ))
        let week = (0..<7).map { offset in
            date(2026, 7, 20 + offset, calendar: calendar)
        }

        #expect(schedule.sprintNumbers(for: week) == [8, 9])
        #expect(schedule.sprintNumbers(for: [date(2026, 7, 6, calendar: calendar)]).isEmpty)
    }

    @Test
    func defaultStoreStateIsDisabledAndCorruptionFallsBackToIt() {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.defaults.set(Data("not JSON".utf8), forKey: "sprints.test")

        let store = SprintScheduleSettingsStore(
            userDefaults: fixture.defaults,
            key: "sprints.test"
        )

        #expect(store.settings.isVisible == false)
        #expect(store.settings.startDate == nil)
    }

    @Test
    func configuringStoreEnablesAndPersistsFourteenDaySchedule() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let start = try #require(CalendarDate(year: 2026, month: 7, day: 8))
        let store = SprintScheduleSettingsStore(
            userDefaults: fixture.defaults,
            key: "sprints.test"
        )

        store.configure(startDate: start, firstSprintNumber: 8)

        #expect(store.settings.isVisible)
        #expect(store.settings.startDate == start)
        #expect(store.settings.firstSprintNumber == 8)
        #expect(store.settings.defaultLengthInDays == 14)
        let restored = SprintScheduleSettingsStore(
            userDefaults: fixture.defaults,
            key: "sprints.test"
        )
        #expect(restored.settings == store.settings)
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func defaultsFixture() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "QuickCalTests.SprintSchedule.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
