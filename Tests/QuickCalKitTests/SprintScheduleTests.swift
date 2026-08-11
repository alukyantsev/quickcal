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
    func individualLengthOverrideRecalculatesAllFollowingSprints() throws {
        let calendar = calendar()
        let start = try #require(CalendarDate(year: 2026, month: 7, day: 8))
        let schedule = try #require(SprintSchedule(
            startDate: start,
            firstSprintNumber: 8,
            lengthOverrides: [.init(sprintNumber: 8, lengthInDays: 10)],
            timeZone: calendar.timeZone
        ))

        #expect(schedule.sprint(for: date(2026, 7, 17, calendar: calendar))?.number == 8)
        #expect(schedule.sprint(for: date(2026, 7, 18, calendar: calendar))?.number == 9)
        #expect(schedule.sprint(for: date(2026, 7, 31, calendar: calendar))?.number == 9)
        #expect(schedule.sprint(for: date(2026, 8, 1, calendar: calendar))?.number == 10)
        #expect(schedule.sprint(number: 9)?.startDate == CalendarDate(year: 2026, month: 7, day: 18))
    }

    @Test
    func pauseExcludesDatesAndStartsNewNumberAfterItsEnd() throws {
        let calendar = calendar()
        let start = try #require(CalendarDate(year: 2026, month: 12, day: 20))
        let pauseStart = try #require(CalendarDate(year: 2026, month: 12, day: 27))
        let pauseEnd = try #require(CalendarDate(year: 2027, month: 1, day: 4))
        let schedule = try #require(SprintSchedule(
            startDate: start,
            firstSprintNumber: 42,
            pauses: [.init(startDate: pauseStart, endDate: pauseEnd)],
            timeZone: calendar.timeZone
        ))

        #expect(schedule.sprint(for: date(2026, 12, 26, calendar: calendar))?.number == 42)
        #expect(schedule.sprint(for: date(2026, 12, 27, calendar: calendar)) == nil)
        #expect(schedule.sprint(for: date(2027, 1, 4, calendar: calendar)) == nil)
        #expect(schedule.sprint(for: date(2027, 1, 5, calendar: calendar))?.number == 43)
        #expect(schedule.sprintNumbers(for: [
            date(2026, 12, 28, calendar: calendar),
            date(2027, 1, 5, calendar: calendar),
        ]) == [43])
    }

    @Test
    func invalidExceptionsAreRejectedBeforeTheyReachTheSchedule() throws {
        let calendar = calendar()
        let start = try #require(CalendarDate(year: 2026, month: 7, day: 8))
        let firstPauseStart = try #require(CalendarDate(year: 2026, month: 7, day: 20))
        let firstPauseEnd = try #require(CalendarDate(year: 2026, month: 7, day: 22))
        let overlappingStart = try #require(CalendarDate(year: 2026, month: 7, day: 22))
        let overlappingEnd = try #require(CalendarDate(year: 2026, month: 7, day: 24))

        #expect(SprintSchedule(
            startDate: start,
            firstSprintNumber: 8,
            lengthOverrides: [.init(sprintNumber: 8, lengthInDays: 0)],
            timeZone: calendar.timeZone
        ) == nil)
        #expect(SprintSchedule(
            startDate: start,
            firstSprintNumber: 8,
            pauses: [
                .init(startDate: firstPauseStart, endDate: firstPauseEnd),
                .init(startDate: overlappingStart, endDate: overlappingEnd),
            ],
            timeZone: calendar.timeZone
        ) == nil)
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

    @Test
    func storePersistsOverridesAndRejectsInvalidPause() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let start = try #require(CalendarDate(year: 2026, month: 7, day: 8))
        let pauseStart = try #require(CalendarDate(year: 2026, month: 7, day: 20))
        let pauseEnd = try #require(CalendarDate(year: 2026, month: 7, day: 24))
        let store = SprintScheduleSettingsStore(userDefaults: fixture.defaults, key: "sprints.test")
        store.configure(startDate: start, firstSprintNumber: 8)

        #expect(store.setLength(ofSprint: 8, to: 10))
        #expect(store.addPause(from: pauseStart, through: pauseEnd))
        #expect(!store.addPause(from: pauseStart, through: pauseEnd))

        let restored = SprintScheduleSettingsStore(userDefaults: fixture.defaults, key: "sprints.test")
        #expect(restored.settings.lengthOverrides == [.init(sprintNumber: 8, lengthInDays: 10)])
        #expect(restored.settings.pauses == [.init(startDate: pauseStart, endDate: pauseEnd)])
    }

    @Test
    func extendingSprintReclaimsOnlyTheOverlappingPartOfAPause() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let start = try #require(CalendarDate(year: 2026, month: 7, day: 8))
        let pauseStart = try #require(CalendarDate(year: 2026, month: 7, day: 18))
        let pauseEnd = try #require(CalendarDate(year: 2026, month: 7, day: 25))
        let expectedPauseStart = try #require(CalendarDate(year: 2026, month: 7, day: 22))
        let store = SprintScheduleSettingsStore(userDefaults: fixture.defaults, key: "sprints.test")
        store.configure(startDate: start, firstSprintNumber: 8)
        #expect(store.addPause(from: pauseStart, through: pauseEnd))

        #expect(store.setLength(ofSprint: 8, to: 14))
        #expect(store.settings.pauses == [
            .init(startDate: expectedPauseStart, endDate: pauseEnd),
        ])

        let schedule = try #require(store.settings.schedule)
        #expect(schedule.sprint(number: 8)?.endDate == CalendarDate(year: 2026, month: 7, day: 21))
        #expect(schedule.sprint(for: date(2026, 7, 22, calendar: calendar())) == nil)
    }

    @Test
    func removingPauseMakesItsDatesPartOfTheSprintAgain() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let start = try #require(CalendarDate(year: 2026, month: 7, day: 8))
        let pauseStart = try #require(CalendarDate(year: 2026, month: 7, day: 18))
        let pauseEnd = try #require(CalendarDate(year: 2026, month: 7, day: 20))
        let store = SprintScheduleSettingsStore(userDefaults: fixture.defaults, key: "sprints.test")
        store.configure(startDate: start, firstSprintNumber: 8)
        #expect(store.addPause(from: pauseStart, through: pauseEnd))

        #expect(store.removePause(.init(startDate: pauseStart, endDate: pauseEnd)))
        #expect(store.settings.pauses.isEmpty)
        #expect(try #require(store.settings.schedule).sprint(for: date(2026, 7, 18, calendar: calendar()))?.number == 8)
    }

    @Test
    func versionOnePayloadMigratesWithoutDiscardingConfiguredSchedule() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let payload = """
        {"version":1,"isVisible":true,"startDate":{"year":2026,"month":7,"day":8},"firstSprintNumber":8,"defaultLengthInDays":14}
        """
        fixture.defaults.set(Data(payload.utf8), forKey: "sprints.test")

        let store = SprintScheduleSettingsStore(userDefaults: fixture.defaults, key: "sprints.test")

        #expect(store.settings.version == SprintScheduleSettings.currentVersion)
        #expect(store.settings.isVisible)
        #expect(store.settings.lengthOverrides.isEmpty)
        #expect(store.settings.pauses.isEmpty)
    }

    @Test
    func reconfiguringBaseSchedulePreservesValidExceptions() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let start = try #require(CalendarDate(year: 2026, month: 7, day: 8))
        let replacementStart = try #require(CalendarDate(year: 2026, month: 7, day: 9))
        let pauseStart = try #require(CalendarDate(year: 2026, month: 7, day: 20))
        let pauseEnd = try #require(CalendarDate(year: 2026, month: 7, day: 24))
        let store = SprintScheduleSettingsStore(userDefaults: fixture.defaults, key: "sprints.test")
        store.configure(startDate: start, firstSprintNumber: 8)
        _ = store.setLength(ofSprint: 8, to: 10)
        _ = store.addPause(from: pauseStart, through: pauseEnd)

        store.configure(startDate: replacementStart, firstSprintNumber: 8)

        #expect(store.settings.lengthOverrides == [.init(sprintNumber: 8, lengthInDays: 10)])
        #expect(store.settings.pauses == [.init(startDate: pauseStart, endDate: pauseEnd)])
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
