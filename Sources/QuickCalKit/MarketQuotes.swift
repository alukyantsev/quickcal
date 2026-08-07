import Foundation

public struct MarketQuoteSettings: Codable, Sendable, Equatable {
    public static let defaultTickers = ["USDRUBF", "EURRUBF", "EUR/USD", "IMOEX"]

    public var isVisible: Bool
    public var tickers: [String]

    public init(isVisible: Bool = false, tickers: [String] = MarketQuoteSettings.defaultTickers) {
        self.isVisible = isVisible
        self.tickers = Self.normalizedTickers(tickers)
    }

    public static func normalizedTickers(from input: String) -> [String] {
        normalizedTickers(input.split(separator: ",", omittingEmptySubsequences: false).map(String.init))
    }

    public static func normalizedTickers(_ tickers: [String]) -> [String] {
        var seen = Set<String>()
        return tickers.compactMap { ticker in
            let normalized = normalizedTicker(ticker)
            return seen.insert(normalized).inserted ? normalized : nil
        }
    }

    public static func normalizedTicker(_ ticker: String) -> String {
        let compact = ticker
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
        switch compact {
        case "USD/RUBFUT", "USDRUBF":
            return "USDRUBF"
        case "EUR/RUBFUT", "EURRUBF":
            return "EURRUBF"
        case "EUR/USD":
            return "EUR/USD"
        default:
            return compact
        }
    }
}

public struct MarketQuote: Codable, Sendable, Equatable {
    public let ticker: String
    public let displayName: String
    public let price: Double
    public let change: Double
    public let changePercent: Double
    public let dataDate: Date

    public init(
        ticker: String,
        displayName: String,
        price: Double,
        change: Double,
        changePercent: Double,
        dataDate: Date
    ) {
        self.ticker = ticker
        self.displayName = displayName
        self.price = price
        self.change = change
        self.changePercent = changePercent
        self.dataDate = dataDate
    }
}

public struct MarketQuoteSnapshot: Codable, Sendable, Equatable {
    public let quotes: [MarketQuote]

    public init(quotes: [MarketQuote]) {
        self.quotes = quotes
    }
}

public struct MarketQuoteCacheEntry: Codable, Sendable, Equatable {
    public static let maximumAgeInCalendarDays = 7

    public let snapshot: MarketQuoteSnapshot
    public let fetchedAt: Date

    public init(snapshot: MarketQuoteSnapshot, fetchedAt: Date) {
        self.snapshot = snapshot
        self.fetchedAt = fetchedAt
    }

    public func isUsable(at date: Date, calendar: Calendar = .current) -> Bool {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: fetchedAt),
            to: calendar.startOfDay(for: date)
        ).day ?? .max
        return (0...Self.maximumAgeInCalendarDays).contains(days)
    }
}

public protocol MarketQuoteProviding: Sendable {
    func quote(for ticker: String) async throws -> MarketQuote
}
