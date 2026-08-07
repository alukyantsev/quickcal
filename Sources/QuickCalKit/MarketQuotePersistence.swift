import Combine
import Foundation

@MainActor
public final class MarketQuoteSettingsStore: ObservableObject {
    public static let defaultKey = "marketQuoteSettings.v1"

    @Published public private(set) var settings: MarketQuoteSettings

    private let userDefaults: UserDefaults
    private let key: String

    public init(userDefaults: UserDefaults = .standard, key: String = MarketQuoteSettingsStore.defaultKey) {
        self.userDefaults = userDefaults
        self.key = key
        let storedSettings = try? userDefaults.data(forKey: key).flatMap {
            try JSONDecoder().decode(MarketQuoteSettings.self, from: $0)
        }
        let migratedSettings = storedSettings.map { stored in
            guard stored.tickers == MarketQuoteSettings.previousDefaultTickers else { return stored }
            return MarketQuoteSettings(isVisible: stored.isVisible)
        }
        settings = migratedSettings ?? MarketQuoteSettings()
        if let storedSettings, storedSettings != settings {
            persist(settings)
        }
    }

    public func update(_ settings: MarketQuoteSettings) {
        self.settings = MarketQuoteSettings(isVisible: settings.isVisible, tickers: settings.tickers)
        persist(self.settings)
    }

    private func persist(_ settings: MarketQuoteSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: key)
    }
}

@MainActor
public final class MarketQuoteCacheStore {
    public static let defaultKey = "marketQuoteCache.v1"

    private let userDefaults: UserDefaults
    private let key: String

    public init(userDefaults: UserDefaults = .standard, key: String = MarketQuoteCacheStore.defaultKey) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func load() -> MarketQuoteCacheEntry? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MarketQuoteCacheEntry.self, from: data)
    }

    public func save(_ entry: MarketQuoteCacheEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        userDefaults.set(data, forKey: key)
    }

    public func remove() {
        userDefaults.removeObject(forKey: key)
    }
}
