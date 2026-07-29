import Combine
import Foundation
import Testing
import QuickCalKit

@Suite
@MainActor
struct SelectedDatesStoreTests {
    @Test
    func calendarDateAcceptsGregorianComponentsAndRejectsInvalidDates() throws {
        let leapDay = try #require(CalendarDate(year: 2028, month: 2, day: 29))

        #expect(leapDay.year == 2028)
        #expect(leapDay.month == 2)
        #expect(leapDay.day == 29)
        #expect(CalendarDate(year: 2026, month: 2, day: 29) == nil)
        #expect(CalendarDate(year: 2026, month: 13, day: 1) == nil)
    }

    @Test
    func calendarDateRoundTripsWithoutTimezoneDrift() throws {
        let civilDate = try #require(CalendarDate(year: 2026, month: 7, day: 29))
        let kiribati = try #require(TimeZone(secondsFromGMT: 14 * 60 * 60))
        let hawaii = try #require(TimeZone(secondsFromGMT: -10 * 60 * 60))

        let kiribatiDate = try #require(civilDate.date(in: kiribati))
        let hawaiiDate = try #require(civilDate.date(in: hawaii))

        #expect(kiribatiDate != hawaiiDate)
        #expect(CalendarDate(date: kiribatiDate, timeZone: kiribati) == civilDate)
        #expect(CalendarDate(date: hawaiiDate, timeZone: hawaii) == civilDate)
    }

    @Test
    func togglePersistsAddAndRemove() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let selectedDate = try #require(CalendarDate(year: 2026, month: 7, day: 29))
        let store = SelectedDatesStore(
            userDefaults: fixture.defaults,
            key: "selectedDates.test"
        )

        #expect(!store.contains(selectedDate))

        store.toggle(selectedDate)
        #expect(store.contains(selectedDate))

        let restored = SelectedDatesStore(
            userDefaults: fixture.defaults,
            key: "selectedDates.test"
        )
        #expect(restored.selectedDates == [selectedDate])

        restored.toggle(selectedDate)
        #expect(!restored.contains(selectedDate))

        let restoredAfterRemoval = SelectedDatesStore(
            userDefaults: fixture.defaults,
            key: "selectedDates.test"
        )
        #expect(restoredAfterRemoval.selectedDates.isEmpty)
    }

    @Test
    func togglePublishesSelectionChangeForSwiftUI() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let selectedDate = try #require(CalendarDate(year: 2026, month: 7, day: 29))
        let store = SelectedDatesStore(
            userDefaults: fixture.defaults,
            key: "selectedDates.test"
        )
        var changeCount = 0
        let subscription = store.objectWillChange.sink {
            changeCount += 1
        }

        store.toggle(selectedDate)

        #expect(changeCount == 1)
        withExtendedLifetime(subscription) {}
    }

    @Test
    func restoresSelectedDatesFromJSON() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let first = try #require(CalendarDate(year: 2026, month: 7, day: 29))
        let second = try #require(CalendarDate(year: 2026, month: 8, day: 1))
        let data = try JSONEncoder().encode([first, second])
        fixture.defaults.set(data, forKey: "selectedDates.test")

        let store = SelectedDatesStore(
            userDefaults: fixture.defaults,
            key: "selectedDates.test"
        )

        #expect(store.selectedDates == [first, second])
    }

    @Test
    func corruptedJSONRestoresAnEmptySelection() {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.defaults.set(
            Data(#"[{"year":2026,"month":2,"day":30}]"#.utf8),
            forKey: "selectedDates.test"
        )

        let store = SelectedDatesStore(
            userDefaults: fixture.defaults,
            key: "selectedDates.test"
        )

        #expect(store.selectedDates.isEmpty)
    }

    private func defaultsFixture() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "QuickCalTests.SelectedDatesStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
