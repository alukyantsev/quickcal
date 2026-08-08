import AppKit
import Foundation
import SwiftUI
import Testing
@testable import QuickCal
import QuickCalKit

@Suite(.serialized)
@MainActor
struct READMEProductScreenshotTests {
    private let snapshotDate = Date(timeIntervalSince1970: 1_786_174_240)

    private actor QuoteProvider: MarketQuoteProviding {
        func quote(for ticker: String) async throws -> MarketQuote {
            let quote = switch ticker {
            case "USDRUBF": ("USD/RUB FUT", 82.95, 0.64, 0.78)
            case "EURRUBF": ("EUR/RUB FUT", 96.74, -0.31, -0.32)
            case "EUR/USD": ("EUR/USD FUT", 1.1662, 0.0021, 0.18)
            case "IMOEX": ("IMOEX", 2_734.18, 12.64, 0.46)
            case "SP500F": ("S&P 500 FUT", 6_312.44, -18.32, -0.29)
            case "GLDRUBF": ("GOLD/RUB FUT", 8_736.10, 41.50, 0.48)
            case "BRENT": ("BRENT", 66.84, -0.52, -0.77)
            case "MOEXBTC": ("BITCOIN", 9_231_000.0, 98_400.0, 1.08)
            default: (ticker, 0.0, 0.0, 0.0)
            }
            return MarketQuote(
                ticker: ticker,
                displayName: quote.0,
                price: quote.1,
                change: quote.2,
                changePercent: quote.3,
                dataDate: Date(timeIntervalSince1970: 1_786_174_240)
            )
        }
    }

    private actor WeatherProvider: WeatherForecastProviding {
        private let forecast: WeatherForecast

        init(forecast: WeatherForecast) {
            self.forecast = forecast
        }

        func searchLocations(query: String) async throws -> [WeatherLocation] { [] }

        func forecast(for location: WeatherLocation) async throws -> WeatherForecast {
            forecast
        }
    }

    private final class LocationService: WeatherLocationServicing {
        var authorizationStatus: WeatherLocationAuthorization = .denied
        var authorizationStatusChanged: (@MainActor (WeatherLocationAuthorization) -> Void)?

        func requestAuthorization() {}
        func currentLocation() async throws -> WeatherLocation { fatalError("not used") }
    }

    @Test
    func rendersCurrentProductScreenshotsForREADME() async throws {
        guard let outputDirectory = ProcessInfo.processInfo.environment[
            "QUICKCAL_README_SCREENSHOT_DIR"
        ] else {
            return
        }

        let suiteName = "QuickCalTests.READMEProductScreenshots.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let previousLanguages = UserDefaults.standard.object(forKey: "AppleLanguages")
        let previousSelectedDates = UserDefaults.standard.data(
            forKey: SelectedDatesStore.defaultKey
        )
        UserDefaults.standard.set(["ru-RU"], forKey: "AppleLanguages")
        let selectedVacation = [8, 9, 10, 11].compactMap {
            CalendarDate(year: 2026, month: 8, day: $0)
        }
        UserDefaults.standard.set(
            try JSONEncoder().encode(selectedVacation),
            forKey: SelectedDatesStore.defaultKey
        )
        defer {
            if let previousLanguages {
                UserDefaults.standard.set(previousLanguages, forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            }
            if let previousSelectedDates {
                UserDefaults.standard.set(
                    previousSelectedDates,
                    forKey: SelectedDatesStore.defaultKey
                )
            } else {
                UserDefaults.standard.removeObject(forKey: SelectedDatesStore.defaultKey)
            }
        }
        defaults.set(QuickCalTheme.systemLight.rawValue, forKey: QuickCalThemeStore.defaultKey)

        let controller = QuoteController(
            settingsStore: MarketQuoteSettingsStore(userDefaults: defaults, key: "settings"),
            cacheStore: MarketQuoteCacheStore(userDefaults: defaults, key: "cache"),
            provider: QuoteProvider(),
            now: { Date(timeIntervalSince1970: 1_786_174_240) }
        )
        controller.setVisibility(true)
        await controller.refreshNow()

        let location = WeatherLocation(
            displayName: "Москва",
            countryCode: "RU",
            latitude: 55.75,
            longitude: 37.62
        )
        let weatherStart = Date().addingTimeInterval(3_600)
        let hourOffsets = Array(0...15)
        let hourly: [WeatherForecastPoint] = hourOffsets.map { offset in
            WeatherForecastPoint(
                timestamp: weatherStart.addingTimeInterval(Double(offset) * 3_600),
                temperatureCelsius: 18 + Double(offset / 4),
                relativeHumidity: 58,
                precipitationProbability: offset == 8 ? 35 : 5,
                weatherCode: offset == 8 ? 2 : 0
            )
        }
        let forecast = WeatherForecast(location: location, hourly: hourly)
        let weatherSettings = WeatherSettingsStore(
            userDefaults: defaults,
            key: "weather-settings"
        )
        weatherSettings.update(WeatherSettings(
            isVisible: true,
            manualLocation: location
        ))
        let weatherController = WeatherController(
            settingsStore: weatherSettings,
            cacheStore: WeatherForecastCacheStore(
                userDefaults: defaults,
                key: "weather-cache"
            ),
            provider: WeatherProvider(forecast: forecast),
            locationService: LocationService(),
            now: { Date(timeIntervalSince1970: 1_786_174_240) }
        )
        let refreshCoordinator = ForegroundRefreshCoordinator(
            weatherController: weatherController,
            quoteController: controller,
            now: { Date(timeIntervalSince1970: 1_786_174_240) }
        )
        await refreshCoordinator.refreshNow()

        let store = QuickCalThemeStore(userDefaults: defaults)
        let overviewRenderer = ImageRenderer(content: CalendarPopoverView(
                themeStore: store,
                weatherController: weatherController,
                quoteController: controller,
                refreshCoordinator: refreshCoordinator,
                usesWeatherWheelPager: false,
                onThemeChanged: { _ in }
            ))
        overviewRenderer.scale = 2
        try save(
            try #require(overviewRenderer.nsImage),
            to: URL(fileURLWithPath: outputDirectory)
                .appendingPathComponent("quickcal-v2.1-quotes-overview.png")
        )

        let settingsView = CalendarPopoverView(
                themeStore: store,
                weatherController: weatherController,
                quoteController: controller,
                refreshCoordinator: refreshCoordinator,
                initialActivePanel: .options,
                usesWeatherWheelPager: false,
                onThemeChanged: { _ in }
            )
        try save(
            try #require(renderInHostingView(settingsView)),
            to: URL(fileURLWithPath: outputDirectory)
                .appendingPathComponent("quickcal-v2.1-settings.png")
        )

        let rail = QuoteRailView(controller: controller)
            .environment(\.quickCalThemeStyle, QuickCalThemeStyle(theme: .titaniumChronoDark))
            .frame(width: 360)
            .padding(12)
            .background(QuickCalThemeBackground(theme: .titaniumChronoDark))
        let detailRenderer = ImageRenderer(content: rail)
        detailRenderer.scale = 2
        try save(
            try #require(detailRenderer.nsImage),
            to: URL(fileURLWithPath: outputDirectory)
                .appendingPathComponent("quickcal-v2.1-quotes-detail.png")
        )
    }

    private func save(_ image: NSImage, to url: URL) throws {
        let data = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: data))
        let pngData = try #require(representation.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try pngData.write(to: url, options: .atomic)
    }

    private func renderInHostingView<V: View>(_ view: V) -> NSImage? {
        let hostingView = NSHostingView(rootView: view)
        let size = hostingView.fittingSize
        guard size.width > 0, size.height > 0 else { return nil }
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        let pixelWidth = Int(size.width * 2)
        let pixelHeight = Int(size.height * 2)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        bitmap.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }
}
