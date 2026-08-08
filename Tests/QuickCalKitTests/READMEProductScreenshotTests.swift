import AppKit
import Foundation
import SwiftUI
import Testing
@testable import QuickCal
import QuickCalKit

@Suite(.serialized)
@MainActor
struct READMEProductScreenshotTests {
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
        UserDefaults.standard.set(["ru-RU"], forKey: "AppleLanguages")
        defer {
            if let previousLanguages {
                UserDefaults.standard.set(previousLanguages, forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
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

        let store = QuickCalThemeStore(userDefaults: defaults)
        let overviewRenderer = ImageRenderer(content: CalendarPopoverView(
                themeStore: store,
                quoteController: controller,
                onThemeChanged: { _ in }
            ))
        overviewRenderer.scale = 2
        try save(
            try #require(overviewRenderer.nsImage),
            to: URL(fileURLWithPath: outputDirectory)
                .appendingPathComponent("quickcal-v2.1-quotes-overview.png")
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
}
