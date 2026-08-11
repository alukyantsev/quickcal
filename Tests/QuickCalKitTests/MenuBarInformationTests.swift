import AppKit
import Foundation
import Testing
@testable import QuickCal
import QuickCalKit

@Suite
@MainActor
struct MenuBarInformationSettingsTests {
    @Test
    func defaultsToDisabledAndPersistsTheOptInChoice() {
        let suiteName = "QuickCalTests.MenuBarInformation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = MenuBarInformationSettingsStore(
            userDefaults: defaults,
            key: "menu-bar-information"
        )

        #expect(!store.isEnabled)

        store.setEnabled(true)

        #expect(MenuBarInformationSettingsStore(
            userDefaults: defaults,
            key: "menu-bar-information"
        ).isEnabled)
    }
}

@Suite
@MainActor
struct MenuBarInformationPresentationTests {
    @Test
    func freshWeatherAndIMOEXUseTheApprovedCompactComposition() {
        let now = Date(timeIntervalSince1970: 1_767_268_800)
        let presentation = MenuBarInformationPresentation.make(
            isEnabled: true,
            weatherIsVisible: true,
            weatherState: .fresh(forecast(
                at: now,
                temperature: 18,
                weatherCode: 0
            )),
            quoteIsVisible: true,
            quoteState: .fresh(
                snapshot(price: 2_740.4),
                fetchedAt: now
            ),
            now: now,
            localization: englishLocalization,
            timeZone: utc
        )

        #expect(presentation.weather == MenuBarInformationPresentation.Weather(
            systemImage: "sun.max.fill",
            temperature: "+18°"
        ))
        #expect(presentation.quote == MenuBarInformationPresentation.Quote(
            value: "2740"
        ))
        #expect(presentation.title == "+18° · 2740")
        #expect(presentation.accessibilityLabel == "QuickCal. Weather +18°; current data. IMOEX 2740; current data.")
        #expect(presentation.toolTip == presentation.accessibilityLabel)
    }

    @Test
    func staleValuesStayVisibleAndDescribeTheirFetchTimeInRussian() {
        let now = Date(timeIntervalSince1970: 1_767_268_800)
        let fetchedAt = Date(timeIntervalSince1970: 1_767_259_800)
        let presentation = MenuBarInformationPresentation.make(
            isEnabled: true,
            weatherIsVisible: true,
            weatherState: .stale(
                forecast(at: now, temperature: -5, weatherCode: 3),
                fetchedAt: fetchedAt
            ),
            quoteIsVisible: true,
            quoteState: .stale(
                snapshot(price: 2_281.31),
                fetchedAt: fetchedAt,
                failedTickers: []
            ),
            now: now,
            localization: QuickCalLocalization(
                preferredLanguages: ["ru-RU"],
                systemLocale: Locale(identifier: "ru_RU")
            ),
            timeZone: utc
        )

        #expect(presentation.weather?.temperature == "-5°")
        #expect(presentation.weather?.isStale == true)
        #expect(presentation.weather?.staleAt == fetchedAt)
        #expect(presentation.quote?.text == "2281")
        #expect(presentation.quote?.isStale == true)
        #expect(presentation.quote?.staleAt == fetchedAt)
        #expect(presentation.accessibilityLabel.hasPrefix(
            "QuickCal. Погода -5°; сохранённые данные от "
        ))
        #expect(presentation.accessibilityLabel.contains("IMOEX 2281; сохранённые данные от "))
        #expect(presentation.accessibilityLabel.contains("09:30"))
        #expect(presentation.toolTip == presentation.accessibilityLabel)
    }

    @Test
    func unavailableAndLoadingSourcesDegradeToOneGroupOrTheStandardIcon() {
        let now = Date(timeIntervalSince1970: 1_767_268_800)
        let weatherOnly = MenuBarInformationPresentation.make(
            isEnabled: true,
            weatherIsVisible: true,
            weatherState: .fresh(forecast(at: now, temperature: 7, weatherCode: 2)),
            quoteIsVisible: true,
            quoteState: .loading,
            now: now,
            localization: englishLocalization,
            timeZone: utc
        )
        let quoteOnly = MenuBarInformationPresentation.make(
            isEnabled: true,
            weatherIsVisible: true,
            weatherState: .unavailable,
            quoteIsVisible: true,
            quoteState: .partial(
                snapshot(price: 2_740),
                fetchedAt: now,
                failedTickers: ["SBER"]
            ),
            now: now,
            localization: englishLocalization,
            timeZone: utc
        )
        let none = MenuBarInformationPresentation.make(
            isEnabled: true,
            weatherIsVisible: true,
            weatherState: .unavailable,
            quoteIsVisible: true,
            quoteState: .error(failedTickers: ["IMOEX"]),
            now: now,
            localization: englishLocalization,
            timeZone: utc
        )
        let disabled = MenuBarInformationPresentation.make(
            isEnabled: false,
            weatherIsVisible: true,
            weatherState: .fresh(forecast(at: now, temperature: 7, weatherCode: 2)),
            quoteIsVisible: true,
            quoteState: .fresh(snapshot(price: 2_740), fetchedAt: now),
            now: now,
            localization: englishLocalization,
            timeZone: utc
        )

        #expect(weatherOnly.title == "+7°")
        #expect(weatherOnly.weather != nil)
        #expect(weatherOnly.quote == nil)
        #expect(quoteOnly.title == "2740")
        #expect(quoteOnly.weather == nil)
        #expect(quoteOnly.quote != nil)
        #expect(!none.isDetailed)
        #expect(none.title.isEmpty)
        #expect(none.accessibilityLabel == "QuickCal")
        #expect(!disabled.isDetailed)
    }

    private var englishLocalization: QuickCalLocalization {
        QuickCalLocalization(
            preferredLanguages: ["en-US"],
            systemLocale: Locale(identifier: "en_US")
        )
    }

    private var utc: TimeZone {
        TimeZone(secondsFromGMT: 0)!
    }

    private func forecast(
        at date: Date,
        temperature: Double,
        weatherCode: Int
    ) -> WeatherForecast {
        WeatherForecast(
            location: WeatherLocation(
                displayName: "Moscow",
                latitude: 55.75,
                longitude: 37.62
            ),
            hourly: [WeatherForecastPoint(
                timestamp: date,
                temperatureCelsius: temperature,
                relativeHumidity: 50,
                precipitationProbability: 0,
                weatherCode: weatherCode
            )]
        )
    }

    private func snapshot(price: Double) -> MarketQuoteSnapshot {
        MarketQuoteSnapshot(quotes: [MarketQuote(
            ticker: "IMOEX",
            displayName: "IMOEX",
            price: price,
            change: 0,
            changePercent: 0,
            dataDate: nil
        )])
    }
}

@Suite(.serialized)
@MainActor
struct MenuBarStatusItemRendererTests {
    private final class ActionTarget: NSObject {
        @objc func togglePopover() {}
    }

    @Test
    func detailedAndFallbackRenderingKeepOneVariableWidthPopoverAction() {
        let button = NSStatusBarButton(frame: NSRect(
            x: 0,
            y: 0,
            width: 24,
            height: NSStatusBar.system.thickness
        ))
        let target = ActionTarget()
        button.target = target
        button.action = #selector(ActionTarget.togglePopover)
        let action = button.action

        MenuBarStatusItemRenderer.apply(
            presentation: detailedPresentation,
            to: button
        )

        let detailedWidth = button.fittingSize.width
        #expect(MenuBarStatusItemRenderer.preferredLength == NSStatusItem.variableLength)
        #expect(button.imagePosition == .imageLeading)
        #expect(button.image?.isTemplate == true)
        #expect(button.attributedTitle.string == "+18° · \u{FFFC}\u{00A0}2740")
        #expect(button.target === target)
        #expect(button.action == action)
        #expect(button.accessibilityLabel() == detailedPresentation.accessibilityLabel)
        #expect(button.toolTip == detailedPresentation.toolTip)

        MenuBarStatusItemRenderer.apply(
            presentation: fallbackPresentation,
            to: button
        )

        #expect(button.imagePosition == .imageOnly)
        #expect(button.image?.isTemplate == true)
        #expect(button.attributedTitle.string.isEmpty)
        #expect(detailedWidth > button.fittingSize.width)
        #expect(button.target === target)
        #expect(button.action == action)
        #expect(button.accessibilityLabel() == "QuickCal")
    }

    @Test
    func popoverAnchorsToTheStableTrailingEdgeWithoutResizingTheStatusItem() {
        let compactBounds = NSRect(x: 0, y: 0, width: 24, height: 22)
        let detailedBounds = NSRect(x: 0, y: 0, width: 134, height: 22)
        #expect(
            MenuBarPopoverLayout.positioningRect(in: compactBounds).maxX
                == compactBounds.maxX
        )
        #expect(
            MenuBarPopoverLayout.positioningRect(in: detailedBounds).maxX
                == detailedBounds.maxX
        )
    }

    @Test
    func freshAndStaleGroupsUsePrimaryAndSecondarySystemColors() throws {
        let button = NSStatusBarButton(frame: NSRect(
            x: 0,
            y: 0,
            width: 24,
            height: NSStatusBar.system.thickness
        ))

        MenuBarStatusItemRenderer.apply(
            presentation: detailedPresentation,
            to: button
        )

        let freshWeatherColor = button.attributedTitle.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor
        let freshQuoteColor = button.attributedTitle.attribute(
            .foregroundColor,
            at: button.attributedTitle.length - 1,
            effectiveRange: nil
        ) as? NSColor
        #expect(freshWeatherColor == nil)
        #expect(freshQuoteColor == nil)

        MenuBarStatusItemRenderer.apply(
            presentation: MenuBarInformationPresentation(
                weather: .init(
                    systemImage: "cloud.fill",
                    temperature: "-5°",
                    staleAt: Date(timeIntervalSince1970: 1)
                ),
                quote: .init(
                    value: "2281",
                    staleAt: Date(timeIntervalSince1970: 1)
                ),
                accessibilityLabel: "QuickCal",
                toolTip: "QuickCal"
            ),
            to: button
        )

        let staleWeatherColor = try #require(button.attributedTitle.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor)
        let staleQuoteColor = try #require(button.attributedTitle.attribute(
            .foregroundColor,
            at: button.attributedTitle.length - 1,
            effectiveRange: nil
        ) as? NSColor)
        #expect(button.contentTintColor == nil)
        #expect(staleWeatherColor == .secondaryLabelColor)
        #expect(staleQuoteColor == .secondaryLabelColor)
    }

    @Test
    func freshRenderingLetsTheMenuBarChooseTemplateTintAndUsesTheMarketSymbol() {
        let button = NSStatusBarButton(frame: NSRect(
            x: 0,
            y: 0,
            width: 24,
            height: NSStatusBar.system.thickness
        ))

        MenuBarStatusItemRenderer.apply(
            presentation: detailedPresentation,
            to: button
        )

        #expect(button.contentTintColor == nil)
        #expect(button.attributedTitle.string == "+18° · \u{FFFC}\u{00A0}2740")
        #expect(button.image?.isTemplate == true)
        let attachment = button.attributedTitle.attribute(
            .attachment,
            at: "+18° · ".utf16.count,
            effectiveRange: nil
        ) as? NSTextAttachment
        #expect(attachment?.bounds.size == NSSize(width: 14, height: 14))
    }

    private var detailedPresentation: MenuBarInformationPresentation {
        MenuBarInformationPresentation(
            weather: .init(
                systemImage: "sun.max.fill",
                temperature: "+18°"
            ),
            quote: .init(value: "2740"),
            accessibilityLabel: "QuickCal. Weather +18°; current data. IMOEX 2740; current data.",
            toolTip: "QuickCal. Weather +18°; current data. IMOEX 2740; current data."
        )
    }

    private var fallbackPresentation: MenuBarInformationPresentation {
        MenuBarInformationPresentation(
            weather: nil,
            quote: nil,
            accessibilityLabel: "QuickCal",
            toolTip: "QuickCal"
        )
    }
}
