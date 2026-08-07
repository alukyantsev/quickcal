import AppKit
import Foundation
import SwiftUI
import Testing
@testable import QuickCal
import QuickCalKit

@Suite(.serialized)
@MainActor
struct ThemeRenderingTests {
    @Test
    func supportingCalendarDataStaysVisuallySubordinate() {
        for theme in QuickCalTheme.allCases {
            let style = QuickCalThemeStyle(theme: theme)
            #expect(style.outOfMonthOpacity < 0.7)
            #expect(style.weekNumberOpacity < style.outOfMonthOpacity)
        }

        let signal = QuickCalThemeStyle(theme: .signalGridDark)
        let titanium = QuickCalThemeStyle(theme: .titaniumChronoDark)
        #expect(signal.headerRuleOpacity < titanium.headerRuleOpacity)
        #expect(signal.rowRuleOpacity < titanium.rowRuleOpacity)
    }

    @Test(arguments: QuickCalTheme.allCases)
    func everyThemeRendersAsANonEmptyPopover(theme: QuickCalTheme) throws {
        let suiteName = "QuickCalTests.ThemeRendering.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            theme.rawValue,
            forKey: QuickCalThemeStore.defaultKey
        )
        let store = QuickCalThemeStore(userDefaults: defaults)
        let view = CalendarPopoverView(
            themeStore: store,
            onThemeChanged: { _ in }
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        let image = try #require(renderer.nsImage)

        #expect(image.size.width >= 328)
        #expect(image.size.height >= 300)

        if let outputDirectory = ProcessInfo.processInfo.environment[
            "QUICKCAL_SNAPSHOT_DIR"
        ] {
            try save(
                image,
                to: URL(fileURLWithPath: outputDirectory)
                    .appendingPathComponent(snapshotName(for: theme))
            )
        }
    }

    @Test(arguments: QuickCalTheme.allCases)
    func selectedDayOffKeepsItsSemanticMarker(
        theme: QuickCalTheme
    ) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 2)
        ))
        let calendarDate = try #require(CalendarDate(
            date: date,
            timeZone: calendar.timeZone
        ))
        let month = try #require(CalendarMonth(
            containing: date,
            calendar: calendar
        ))
        let day = try #require(
            month.weeks
                .flatMap(\.days)
                .first { calendar.isDate($0.date, inSameDayAs: date) }
        )
        let style = QuickCalThemeStyle(theme: theme)
        let localization = QuickCalLocalization(
            preferredLanguages: ["en"],
            systemLocale: Locale(identifier: "en_US")
        )
        let cell = CalendarDayCell(
            day: day,
            calendarDate: calendarDate,
            selectionSegment: .isolated,
            isToday: false,
            workdayStatus: .nonWorking,
            calendar: calendar,
            localization: localization,
            onToggle: { _ in }
        )
        .environment(\.quickCalThemeStyle, style)
        .padding(12)
        .background(QuickCalThemeBackground(theme: theme))
        let renderer = ImageRenderer(content: cell)
        renderer.scale = 2

        let image = try #require(renderer.nsImage)
        #expect(image.size.width >= 58)
        #expect(image.size.height >= 58)

        if let outputDirectory = ProcessInfo.processInfo.environment[
            "QUICKCAL_SNAPSHOT_DIR"
        ] {
            try save(
                image,
                to: URL(fileURLWithPath: outputDirectory)
                    .appendingPathComponent(
                        "quickcal-selected-dayoff-\(theme.rawValue).png"
                    )
            )
        }
    }

    @Test(arguments: QuickCalTheme.allCases)
    func weatherPeriodUsesEveryThemeGrammar(theme: QuickCalTheme) throws {
        let cell = WeatherPeriodCell(
            period: WeatherDisplayPeriod(point: WeatherForecastPoint(
                timestamp: Date(timeIntervalSince1970: 1_767_225_600),
                temperatureCelsius: 3,
                relativeHumidity: 70,
                precipitationProbability: 20,
                weatherCode: 2
            )),
            localization: QuickCalLocalization(
                preferredLanguages: ["en"],
                systemLocale: Locale(identifier: "en_US")
            ),
            showsTrailingDivider: true
        )
        .environment(\.quickCalThemeStyle, QuickCalThemeStyle(theme: theme))
        .frame(width: 80, height: 82)
        .background(QuickCalThemeBackground(theme: theme))
        let renderer = ImageRenderer(content: cell)
        renderer.scale = 2

        let image = try #require(renderer.nsImage)
        #expect(image.size == NSSize(width: 80, height: 82))
    }

    private func snapshotName(for theme: QuickCalTheme) -> String {
        "quickcal-theme-\(theme.rawValue).png"
    }

    private func save(_ image: NSImage, to url: URL) throws {
        let data = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: data))
        let pngData = try #require(
            representation.representation(
                using: .png,
                properties: [:]
            )
        )

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try pngData.write(to: url, options: .atomic)
    }
}
