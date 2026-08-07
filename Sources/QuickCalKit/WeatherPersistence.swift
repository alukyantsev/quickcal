import Combine
import Foundation

@MainActor
public final class WeatherSettingsStore: ObservableObject {
    public static let defaultKey = "weatherSettings.v1"

    @Published public private(set) var settings: WeatherSettings

    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = WeatherSettingsStore.defaultKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
        settings = (try? userDefaults.data(forKey: key).flatMap {
            try JSONDecoder().decode(WeatherSettings.self, from: $0)
        }) ?? WeatherSettings()
    }

    public func update(_ settings: WeatherSettings) {
        self.settings = settings
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: key)
    }
}

@MainActor
public final class WeatherForecastCacheStore {
    public static let defaultKey = "weatherForecastCache.v1"

    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = WeatherForecastCacheStore.defaultKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func load() -> WeatherForecastCacheEntry? {
        guard
            let data = userDefaults.data(forKey: key),
            let entry = try? JSONDecoder().decode(WeatherForecastCacheEntry.self, from: data)
        else {
            return nil
        }
        return entry
    }

    public func save(_ entry: WeatherForecastCacheEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        userDefaults.set(data, forKey: key)
    }

    public func remove() {
        userDefaults.removeObject(forKey: key)
    }
}
