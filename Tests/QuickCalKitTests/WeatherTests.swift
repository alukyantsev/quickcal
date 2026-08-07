import Foundation
import Testing
import QuickCalKit

@Suite
struct OpenMeteoWeatherClientTests {
    private actor RequestRecorder {
        private(set) var requests: [URLRequest] = []
        private var responses: [HTTPDataResponse]

        init(responses: [HTTPDataResponse]) {
            self.responses = responses
        }

        func load(_ request: URLRequest) -> HTTPDataResponse {
            requests.append(request)
            return responses.removeFirst()
        }
    }

    @Test
    func geocodesConcreteLocationsWithOpenMeteoQueryContract() async throws {
        let recorder = RequestRecorder(responses: [HTTPDataResponse(
            data: Data("""
            {"results":[{"name":"Moscow","admin1":"Moscow","country":"Russia","country_code":"RU","latitude":55.75,"longitude":37.62}]}
            """.utf8),
            statusCode: 200
        )])
        let client = try OpenMeteoWeatherClient(loader: HTTPDataLoader { request in
            await recorder.load(request)
        })

        let locations = try await client.searchLocations(query: " Moscow ")

        #expect(locations == [WeatherLocation(
            displayName: "Moscow",
            administrativeArea: "Moscow",
            country: "Russia",
            countryCode: "RU",
            latitude: 55.75,
            longitude: 37.62
        )])
        let request = try #require(await recorder.requests.first)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == "geocoding-api.open-meteo.com")
        #expect(Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        }) == ["name": "Moscow", "count": "10", "language": "en", "format": "json"])
    }

    @Test
    func fetchesAtLeastTwoDaysOfUtcHourlyForecastAndNormalizesPoints() async throws {
        let recorder = RequestRecorder(responses: [HTTPDataResponse(
            data: Data("""
            {"hourly":{"time":[1767225600,1767229200],"temperature_2m":[-4.5,-4.0],"relative_humidity_2m":[91,89],"precipitation_probability":[10,20],"weather_code":[3,51]}}
            """.utf8),
            statusCode: 200
        )])
        let client = try OpenMeteoWeatherClient(loader: HTTPDataLoader { request in
            await recorder.load(request)
        })
        let location = WeatherLocation(displayName: "Moscow", latitude: 55.75, longitude: 37.62)

        let forecast = try await client.forecast(for: location)

        #expect(forecast.location == location)
        #expect(forecast.hourly == [
            WeatherForecastPoint(timestamp: Date(timeIntervalSince1970: 1_767_225_600), temperatureCelsius: -4.5, relativeHumidity: 91, precipitationProbability: 10, weatherCode: 3),
            WeatherForecastPoint(timestamp: Date(timeIntervalSince1970: 1_767_229_200), temperatureCelsius: -4.0, relativeHumidity: 89, precipitationProbability: 20, weatherCode: 51),
        ])
        let request = try #require(await recorder.requests.first)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == "api.open-meteo.com")
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
        #expect(query["latitude"] == "55.75")
        #expect(query["longitude"] == "37.62")
        #expect(query["timeformat"] == "unixtime")
        #expect(query["timezone"] == "UTC")
        #expect(query["forecast_days"] == "2")
        #expect(query["hourly"] == "temperature_2m,relative_humidity_2m,precipitation_probability,weather_code")
    }

    @Test
    func rejectsInsecureEndpointsAndInvalidPayloads() async throws {
        #expect(throws: OpenMeteoWeatherClient.ClientError.insecureEndpoint) {
            try OpenMeteoWeatherClient(
                geocodingEndpoint: URL(string: "http://geocoding-api.open-meteo.com/v1/search")!
            )
        }
        let client = try OpenMeteoWeatherClient(loader: HTTPDataLoader { _ in
            HTTPDataResponse(data: Data("not json".utf8), statusCode: 200)
        })

        await #expect(throws: OpenMeteoWeatherClient.ClientError.decodingFailed) {
            try await client.searchLocations(query: "Moscow")
        }
    }

    @Test
    func reportsHTTPStatusAndMismatchedHourlyArrays() async throws {
        let unavailable = try OpenMeteoWeatherClient(loader: HTTPDataLoader { _ in
            HTTPDataResponse(data: Data(), statusCode: 503)
        })
        await #expect(throws: OpenMeteoWeatherClient.ClientError.httpStatus(503)) {
            try await unavailable.searchLocations(query: "Moscow")
        }

        let invalid = try OpenMeteoWeatherClient(loader: HTTPDataLoader { _ in
            HTTPDataResponse(data: Data("""
            {"hourly":{"time":[1767225600],"temperature_2m":[],"relative_humidity_2m":[91],"precipitation_probability":[10],"weather_code":[3]}}
            """.utf8), statusCode: 200)
        })
        await #expect(throws: OpenMeteoWeatherClient.ClientError.invalidResponse) {
            try await invalid.forecast(for: WeatherLocation(displayName: "Moscow", latitude: 55.75, longitude: 37.62))
        }
    }
}

@Suite
@MainActor
struct WeatherPersistenceTests {
    @Test
    func settingsPersistAllModesIntervalsAndLocationFallback() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let automatic = WeatherLocation(displayName: "Tver", countryCode: "RU", latitude: 56.86, longitude: 35.91)
        let settings = WeatherSettings(
            isVisible: false,
            locationMode: .automatic,
            interval: .twelveHours,
            manualLocation: WeatherLocation(displayName: "Moscow", latitude: 55.75, longitude: 37.62),
            automaticLocation: automatic
        )
        let store = WeatherSettingsStore(userDefaults: fixture.defaults, key: "settings")

        store.update(settings)
        let restored = WeatherSettingsStore(userDefaults: fixture.defaults, key: "settings")

        #expect(restored.settings == settings)
        #expect(restored.settings.resolvedLocation == automatic)
        #expect(WeatherInterval.allCases.map(\.rawValue) == [2, 4, 8, 12])
    }

    @Test
    func invalidStoredSettingsAndCacheAreIgnored() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.defaults.set(Data("broken".utf8), forKey: "settings")
        fixture.defaults.set(Data("broken".utf8), forKey: "cache")

        let settings = WeatherSettingsStore(userDefaults: fixture.defaults, key: "settings")
        let cache = WeatherForecastCacheStore(userDefaults: fixture.defaults, key: "cache")

        #expect(settings.settings == WeatherSettings())
        #expect(cache.load() == nil)
    }

    @Test
    func cacheSurvivesStoreRecreation() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let forecast = WeatherForecast(
            location: WeatherLocation(displayName: "Moscow", latitude: 55.75, longitude: 37.62),
            hourly: [WeatherForecastPoint(timestamp: Date(timeIntervalSince1970: 1_767_225_600), temperatureCelsius: 3, relativeHumidity: 70, precipitationProbability: 20, weatherCode: 2)]
        )
        let entry = WeatherForecastCacheEntry(forecast: forecast, fetchedAt: Date(timeIntervalSince1970: 1_767_225_600))
        let cache = WeatherForecastCacheStore(userDefaults: fixture.defaults, key: "cache")

        cache.save(entry)

        #expect(WeatherForecastCacheStore(userDefaults: fixture.defaults, key: "cache").load() == entry)
    }

    private func defaultsFixture() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "QuickCalTests.Weather.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
