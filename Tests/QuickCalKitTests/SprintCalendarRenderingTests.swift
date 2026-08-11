import AppKit
import Foundation
import SwiftUI
import Testing
@testable import QuickCal
import QuickCalKit

@Suite(.serialized)
@MainActor
struct SprintCalendarRenderingTests {
    @Test
    func calendarGridRendersSprintColumnAndCurrentSprintHighlight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let reference = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 20)
        ))
        let month = try #require(CalendarMonth(containing: reference, calendar: calendar))
        let start = try #require(CalendarDate(year: 2026, month: 7, day: 8))
        let schedule = try #require(SprintSchedule(
            startDate: start,
            firstSprintNumber: 8,
            timeZone: calendar.timeZone
        ))
        let grid = CalendarGridView(
            month: month,
            showWeekNumbers: true,
            sprintSchedule: schedule,
            today: reference,
            selectedDates: [],
            workdayStatus: { _ in .working },
            localization: QuickCalLocalization(
                preferredLanguages: ["en"],
                systemLocale: Locale(identifier: "en_US")
            ),
            onToggleDate: { _ in }
        )
        .environment(\.quickCalThemeStyle, QuickCalThemeStyle(theme: .systemLight))

        let renderer = ImageRenderer(content: grid)
        renderer.scale = 2
        let image = try #require(renderer.nsImage)

        #expect(image.size.width >= 320)
        #expect(image.size.height >= 250)
    }

    @Test
    func dayAccessibilityNamesSprintAndHigherPriorityStates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 20)
        ))
        let calendarDate = try #require(CalendarDate(date: date, timeZone: calendar.timeZone))
        let month = try #require(CalendarMonth(containing: date, calendar: calendar))
        let day = try #require(month.weeks.flatMap(\.days).first {
            calendar.isDate($0.date, inSameDayAs: date)
        })
        let localization = QuickCalLocalization(
            preferredLanguages: ["en"],
            systemLocale: Locale(identifier: "en_US")
        )
        let cell = CalendarDayCell(
            day: day,
            calendarDate: calendarDate,
            selectionSegment: .isolated,
            isToday: true,
            isInCurrentSprint: true,
            sprintNumber: 8,
            workdayStatus: .nonWorking,
            calendar: calendar,
            localization: localization,
            onToggle: { _ in }
        )

        #expect(cell.accessibilityValue == "Sprint 8, Today, Selected, Day off, Current sprint")
    }
}
