import Foundation

public struct WeatherLocation: Codable, Sendable, Equatable, Hashable {
    public let displayName: String
    public let administrativeArea: String?
    public let country: String?
    public let countryCode: String?
    public let latitude: Double
    public let longitude: Double

    public init(
        displayName: String,
        administrativeArea: String? = nil,
        country: String? = nil,
        countryCode: String? = nil,
        latitude: Double,
        longitude: Double
    ) {
        self.displayName = displayName
        self.administrativeArea = administrativeArea
        self.country = country
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum WeatherLocationMode: String, Codable, Sendable, CaseIterable {
    case manual
    case automatic
}

public enum WeatherInterval: Int, Codable, Sendable, CaseIterable {
    case twoHours = 2
    case fourHours = 4
    case eightHours = 8
    case twelveHours = 12
}

public struct WeatherSettings: Codable, Sendable, Equatable {
    public var isVisible: Bool
    public var locationMode: WeatherLocationMode
    public var interval: WeatherInterval
    public var manualLocation: WeatherLocation?
    public var automaticLocation: WeatherLocation?

    public init(
        isVisible: Bool = true,
        locationMode: WeatherLocationMode = .manual,
        interval: WeatherInterval = .twoHours,
        manualLocation: WeatherLocation? = nil,
        automaticLocation: WeatherLocation? = nil
    ) {
        self.isVisible = isVisible
        self.locationMode = locationMode
        self.interval = interval
        self.manualLocation = manualLocation
        self.automaticLocation = automaticLocation
    }

    public var resolvedLocation: WeatherLocation? {
        switch locationMode {
        case .manual:
            manualLocation ?? automaticLocation
        case .automatic:
            automaticLocation ?? manualLocation
        }
    }
}

public struct WeatherForecastPoint: Codable, Sendable, Equatable {
    /// UTC instant supplied by the provider. Presentation converts it to the Mac time zone.
    public let timestamp: Date
    public let temperatureCelsius: Double
    public let relativeHumidity: Int
    public let precipitationProbability: Int
    public let weatherCode: Int

    public init(
        timestamp: Date,
        temperatureCelsius: Double,
        relativeHumidity: Int,
        precipitationProbability: Int,
        weatherCode: Int
    ) {
        self.timestamp = timestamp
        self.temperatureCelsius = temperatureCelsius
        self.relativeHumidity = relativeHumidity
        self.precipitationProbability = precipitationProbability
        self.weatherCode = weatherCode
    }
}

public struct WeatherForecast: Codable, Sendable, Equatable {
    public let location: WeatherLocation
    public let hourly: [WeatherForecastPoint]

    public init(location: WeatherLocation, hourly: [WeatherForecastPoint]) {
        self.location = location
        self.hourly = hourly
    }
}

public struct WeatherForecastCacheEntry: Codable, Sendable, Equatable {
    public let forecast: WeatherForecast
    public let fetchedAt: Date

    public init(forecast: WeatherForecast, fetchedAt: Date) {
        self.forecast = forecast
        self.fetchedAt = fetchedAt
    }
}

public protocol WeatherForecastProviding: Sendable {
    func searchLocations(query: String) async throws -> [WeatherLocation]
    func forecast(for location: WeatherLocation) async throws -> WeatherForecast
}
