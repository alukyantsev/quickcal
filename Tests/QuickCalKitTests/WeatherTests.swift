import Foundation
import Testing
@testable import QuickCal
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
    func defaultSettingsUseFourHourInterval() {
        #expect(WeatherSettings().interval == .fourHours)
    }

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

@Suite(.serialized)
@MainActor
struct WeatherControllerTests {
    private actor ForecastProvider: WeatherForecastProviding {
        enum ProviderError: Error { case unavailable }

        private var responses: [Result<WeatherForecast, Error>]
        private var requestedLocations: [WeatherLocation] = []

        init(responses: [Result<WeatherForecast, Error>]) {
            self.responses = responses
        }

        func searchLocations(query: String) async throws -> [WeatherLocation] { [] }

        func forecast(for location: WeatherLocation) async throws -> WeatherForecast {
            requestedLocations.append(location)
            guard !responses.isEmpty else { throw ProviderError.unavailable }
            return try responses.removeFirst().get()
        }

        func requestCount() -> Int { requestedLocations.count }
        func latestRequestedLocation() -> WeatherLocation? { requestedLocations.last }
    }

    private final class LocationService: WeatherLocationServicing {
        var authorizationStatus: WeatherLocationAuthorization
        var authorizationStatusChanged: (@MainActor (WeatherLocationAuthorization) -> Void)?
        var locationResult: Result<WeatherLocation, Error>
        private(set) var authorizationRequestCount = 0
        private(set) var locationRequestCount = 0

        init(
            authorizationStatus: WeatherLocationAuthorization = .notDetermined,
            locationResult: Result<WeatherLocation, Error>
        ) {
            self.authorizationStatus = authorizationStatus
            self.locationResult = locationResult
        }

        func requestAuthorization() {
            authorizationRequestCount += 1
        }

        func currentLocation() async throws -> WeatherLocation {
            locationRequestCount += 1
            return try locationResult.get()
        }

        func changeAuthorization(to status: WeatherLocationAuthorization) {
            authorizationStatus = status
            authorizationStatusChanged?(status)
        }
    }

    private final class RefreshTimer: WeatherRefreshScheduling {
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

        func fire() {
            action?()
        }
    }

    private final class TestClock: @unchecked Sendable {
        var value: Date

        init(_ value: Date) {
            self.value = value
        }

        func now() -> Date { value }
    }

    @Test
    func doesNotRequestLocationUntilAutomaticModeIsExplicitlyEnabled() async {
        let location = fixtureLocation()
        let service = LocationService(locationResult: .success(location))
        let controller = makeController(locationService: service)

        #expect(service.authorizationRequestCount == 0)
        #expect(service.locationRequestCount == 0)
        #expect(controller.state == .noLocation)

        controller.setAutomaticModeEnabled(true)

        #expect(service.authorizationRequestCount == 1)
        #expect(service.locationRequestCount == 0)
    }

    @Test
    func authorizedAutomaticModePersistsLocationAndRefreshesForecast() async {
        let automatic = fixtureLocation(displayName: "Tver")
        let forecast = fixtureForecast(location: automatic)
        let service = LocationService(
            authorizationStatus: .authorized,
            locationResult: .success(automatic)
        )
        let provider = ForecastProvider(responses: [.success(forecast)])
        let controller = makeController(provider: provider, locationService: service)

        controller.setAutomaticModeEnabled(true)
        await controller.refreshNow()

        #expect(controller.settings.locationMode == .automatic)
        #expect(controller.settings.automaticLocation == automatic)
        #expect(controller.state == .fresh(forecast))
        #expect(service.locationRequestCount == 1)
        #expect(await provider.latestRequestedLocation() == automatic)
    }

    @Test
    func foregroundTimerRefreshesAutomaticLocationAndForecastEveryThirtyMinutes() async {
        let automatic = fixtureLocation()
        let forecast = fixtureForecast(location: automatic)
        let service = LocationService(
            authorizationStatus: .authorized,
            locationResult: .success(automatic)
        )
        let provider = ForecastProvider(responses: [.success(forecast)])
        let timer = RefreshTimer()
        let controller = makeController(provider: provider, locationService: service, timer: timer)

        controller.setAutomaticModeEnabled(true)
        await controller.refreshNow()
        controller.startForegroundRefresh()
        timer.fire()
        await Task.yield()
        await Task.yield()

        #expect(timer.interval == WeatherController.foregroundRefreshInterval)
        #expect(service.locationRequestCount == 2)
        #expect(await provider.requestCount() == 2)
    }

    @Test
    func deniedAutomaticLocationUsesManualFallback() async {
        let manual = fixtureLocation(displayName: "Moscow")
        let forecast = fixtureForecast(location: manual)
        let service = LocationService(
            authorizationStatus: .denied,
            locationResult: .failure(ForecastProvider.ProviderError.unavailable)
        )
        let provider = ForecastProvider(responses: [.success(forecast)])
        let controller = makeController(
            settings: WeatherSettings(locationMode: .automatic, manualLocation: manual),
            provider: provider,
            locationService: service
        )

        await controller.refreshNow()

        #expect(service.locationRequestCount == 0)
        #expect(await provider.latestRequestedLocation() == manual)
        #expect(controller.state == .fresh(forecast))
    }

    @Test
    func automaticLocationErrorUsesLastManualFallback() async {
        let manual = fixtureLocation(displayName: "Moscow")
        let forecast = fixtureForecast(location: manual)
        let service = LocationService(
            authorizationStatus: .authorized,
            locationResult: .failure(ForecastProvider.ProviderError.unavailable)
        )
        let provider = ForecastProvider(responses: [.success(forecast)])
        let controller = makeController(
            settings: WeatherSettings(locationMode: .automatic, manualLocation: manual),
            provider: provider,
            locationService: service
        )

        await controller.refreshNow()

        #expect(service.locationRequestCount == 1)
        #expect(await provider.latestRequestedLocation() == manual)
        #expect(controller.state == .fresh(forecast))
    }

    @Test
    func usesStaleCacheForTwentyFourHoursAndKeepsItAfterRefreshFailure() async {
        let clock = TestClock(Date(timeIntervalSince1970: 1_767_225_600))
        let location = fixtureLocation()
        let forecast = fixtureForecast(location: location)
        let cache = WeatherForecastCacheStore(userDefaults: defaultsFixture().defaults, key: UUID().uuidString)
        cache.save(WeatherForecastCacheEntry(
            forecast: forecast,
            fetchedAt: clock.now().addingTimeInterval(-WeatherController.freshCacheLifetime)
        ))
        let controller = makeController(
            settings: WeatherSettings(manualLocation: location),
            cacheStore: cache,
            provider: ForecastProvider(responses: [.failure(ForecastProvider.ProviderError.unavailable)]),
            locationService: LocationService(locationResult: .success(location)),
            now: { clock.now() }
        )

        #expect(controller.state == WeatherPresentationState.stale(forecast, fetchedAt: clock.now().addingTimeInterval(-WeatherController.freshCacheLifetime)))
        await controller.refreshNow()
        #expect(controller.state == WeatherPresentationState.stale(forecast, fetchedAt: clock.now().addingTimeInterval(-WeatherController.freshCacheLifetime)))

        clock.value = clock.now().addingTimeInterval(WeatherController.staleCacheLifetime + 1)
        let expired = makeController(
            settings: WeatherSettings(manualLocation: location),
            cacheStore: cache,
            provider: ForecastProvider(responses: []),
            locationService: LocationService(locationResult: .success(location)),
            now: { clock.now() }
        )
        #expect(expired.state == .unavailable)
    }

    private func makeController(
        settings: WeatherSettings = WeatherSettings(),
        cacheStore: WeatherForecastCacheStore? = nil,
        provider: ForecastProvider = ForecastProvider(responses: []),
        locationService: LocationService,
        timer: RefreshTimer = RefreshTimer(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> WeatherController {
        let defaults = defaultsFixture().defaults
        let settingsStore = WeatherSettingsStore(userDefaults: defaults, key: UUID().uuidString)
        settingsStore.update(settings)
        return WeatherController(
            settingsStore: settingsStore,
            cacheStore: cacheStore ?? WeatherForecastCacheStore(userDefaults: defaults, key: UUID().uuidString),
            provider: provider,
            locationService: locationService,
            timer: timer,
            now: now
        )
    }

    private func fixtureLocation(displayName: String = "Moscow") -> WeatherLocation {
        WeatherLocation(displayName: displayName, countryCode: "RU", latitude: 55.75, longitude: 37.62)
    }

    private func fixtureForecast(location: WeatherLocation) -> WeatherForecast {
        WeatherForecast(
            location: location,
            hourly: [WeatherForecastPoint(
                timestamp: Date(timeIntervalSince1970: 1_767_225_600),
                temperatureCelsius: 3,
                relativeHumidity: 70,
                precipitationProbability: 20,
                weatherCode: 2
            )]
        )
    }

    private func defaultsFixture() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "QuickCalTests.WeatherController.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

@Suite
struct WeatherRailPresentationTests {
    @Test(arguments: WeatherInterval.allCases)
    func intervalSelectsActualForecastPoints(interval: WeatherInterval) throws {
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        let location = WeatherLocation(displayName: "Moscow", latitude: 55.75, longitude: 37.62)
        let forecast = WeatherForecast(
            location: location,
            hourly: (0..<25).map { hour in
                WeatherForecastPoint(
                    timestamp: start.addingTimeInterval(Double(hour) * 3_600),
                    temperatureCelsius: Double(hour),
                    relativeHumidity: 70,
                    precipitationProbability: 20,
                    weatherCode: 0
                )
            }
        )

        let periods = WeatherDisplayPeriod.make(
            from: forecast,
            interval: interval,
            now: start
        )

        #expect(periods.prefix(4).count == 4)
        #expect(periods.prefix(4).map(\.point.timestamp) == [0, interval.rawValue, interval.rawValue * 2, interval.rawValue * 3].map {
            start.addingTimeInterval(Double($0) * 3_600)
        })
    }

    @Test
    func startsAtNearestFuturePointAndMapsWmoSymbolsWithLocalDayNight() {
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        let location = WeatherLocation(displayName: "Moscow", latitude: 55.75, longitude: 37.62)
        let forecast = WeatherForecast(location: location, hourly: [
            WeatherForecastPoint(timestamp: start, temperatureCelsius: 0, relativeHumidity: 60, precipitationProbability: 0, weatherCode: 0),
            WeatherForecastPoint(timestamp: start.addingTimeInterval(3_600), temperatureCelsius: 1, relativeHumidity: 60, precipitationProbability: 0, weatherCode: 95),
        ])

        let periods = WeatherDisplayPeriod.make(
            from: forecast,
            interval: .twoHours,
            now: start.addingTimeInterval(1)
        )

        #expect(periods.map(\.point.timestamp) == [start.addingTimeInterval(3_600)])
        #expect(WeatherDisplayPeriod.symbol(for: 95, at: start) == "cloud.bolt.rain.fill")
        #expect(WeatherDisplayPeriod.symbol(
            for: 0,
            at: start,
            timeZone: TimeZone(secondsFromGMT: 0)!
        ) == "moon.stars.fill")
        #expect(WeatherDisplayPeriod.timeString(
            for: start,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(secondsFromGMT: 3 * 3_600)!
        ) == "03:00")
    }
}
