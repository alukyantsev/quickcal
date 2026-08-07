import Foundation
import SwiftUI
import Testing
@testable import QuickCal
import QuickCalKit

@Suite(.serialized)
@MainActor
struct QuoteControllerTests {
    private actor QuoteProvider: MarketQuoteProviding {
        private var requests: [String] = []

        func quote(for ticker: String) async throws -> MarketQuote {
            requests.append(ticker)
            return MarketQuote(
                ticker: ticker,
                displayName: ticker == "USDRUBF" ? "USD/RUB FUT" : ticker,
                price: 100,
                change: 1,
                changePercent: 1,
                dataDate: Date(timeIntervalSince1970: 1_767_225_600)
            )
        }

        func requestedTickers() -> [String] { requests }
    }

    private final class RefreshTimer: ForegroundRefreshScheduling {
        private(set) var interval: TimeInterval?
        private var action: (@MainActor () -> Void)?

        func schedule(every interval: TimeInterval, action: @escaping @MainActor () -> Void) {
            self.interval = interval
            self.action = action
        }

        func invalidate() {
            interval = nil
            action = nil
        }

        func fire() { action?() }
    }

    private actor ForecastProvider: WeatherForecastProviding {
        private var requests = 0
        let location: WeatherLocation

        init(location: WeatherLocation) { self.location = location }

        func searchLocations(query: String) async throws -> [WeatherLocation] { [] }

        func forecast(for location: WeatherLocation) async throws -> WeatherForecast {
            requests += 1
            return WeatherForecast(location: location, hourly: [])
        }

        func requestCount() -> Int { requests }
    }

    private final class LocationService: WeatherLocationServicing {
        var authorizationStatus: WeatherLocationAuthorization = .notDetermined
        var authorizationStatusChanged: (@MainActor (WeatherLocationAuthorization) -> Void)?
        func requestAuthorization() {}
        func currentLocation() async throws -> WeatherLocation { fatalError("not used") }
    }

    @Test
    func enablingQuotesLoadsTheDefaultRowsInTheirStoredOrder() async {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let provider = QuoteProvider()
        let controller = QuoteController(
            settingsStore: MarketQuoteSettingsStore(userDefaults: fixture.defaults, key: "settings"),
            cacheStore: MarketQuoteCacheStore(userDefaults: fixture.defaults, key: "cache"),
            provider: provider,
            now: { Date(timeIntervalSince1970: 1_767_225_600) }
        )

        #expect(!controller.settings.isVisible)
        controller.setVisibility(true)
        await controller.refreshNow()

        #expect(await provider.requestedTickers() == MarketQuoteSettings.defaultTickers)
        guard case .fresh(let snapshot, _) = controller.state else {
            Issue.record("Expected a quote snapshot")
            return
        }
        #expect(snapshot.quotes.map(\.ticker) == MarketQuoteSettings.defaultTickers)
    }

    @Test
    func oneForegroundTimerRefreshesBothControllers() async {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let location = WeatherLocation(displayName: "Moscow", latitude: 55.75, longitude: 37.62)
        let quoteProvider = QuoteProvider()
        let quoteSettings = MarketQuoteSettingsStore(userDefaults: fixture.defaults, key: "quote-settings")
        quoteSettings.update(MarketQuoteSettings(isVisible: true))
        let quoteController = QuoteController(
            settingsStore: quoteSettings,
            cacheStore: MarketQuoteCacheStore(userDefaults: fixture.defaults, key: "quote-cache"),
            provider: quoteProvider
        )
        let forecastProvider = ForecastProvider(location: location)
        let weatherSettings = WeatherSettingsStore(userDefaults: fixture.defaults, key: "weather-settings")
        weatherSettings.update(WeatherSettings(isVisible: true, manualLocation: location))
        let weatherController = WeatherController(
            settingsStore: weatherSettings,
            cacheStore: WeatherForecastCacheStore(userDefaults: fixture.defaults, key: "weather-cache"),
            provider: forecastProvider,
            locationService: LocationService()
        )
        let timer = RefreshTimer()
        let coordinator = ForegroundRefreshCoordinator(
            weatherController: weatherController,
            quoteController: quoteController,
            timer: timer
        )

        coordinator.start()
        #expect(timer.interval == ForegroundRefreshCoordinator.interval)
        timer.fire()
        for _ in 0..<8 { await Task.yield() }

        #expect(await forecastProvider.requestCount() == 1)
        #expect(await quoteProvider.requestedTickers() == MarketQuoteSettings.defaultTickers)
    }

    @Test
    func quoteRailRendersTheDefaultRowsWithoutASectionTitle() async throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let controller = QuoteController(
            settingsStore: visibleSettingsStore(defaults: fixture.defaults, key: "settings"),
            cacheStore: MarketQuoteCacheStore(userDefaults: fixture.defaults, key: "cache"),
            provider: QuoteProvider()
        )
        await controller.refreshNow()

        let view = QuoteRailView(controller: controller)
            .environment(\.quickCalThemeStyle, QuickCalThemeStyle(theme: .systemLight))
            .frame(width: 320)
        let image = try #require(ImageRenderer(content: view).nsImage)

        #expect(image.size.width == 320)
        #expect(image.size.height >= 80)
    }

    private func visibleSettingsStore(defaults: UserDefaults, key: String) -> MarketQuoteSettingsStore {
        let store = MarketQuoteSettingsStore(userDefaults: defaults, key: key)
        store.update(MarketQuoteSettings(isVisible: true))
        return store
    }

    private func defaultsFixture() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "QuickCalTests.QuoteController.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
