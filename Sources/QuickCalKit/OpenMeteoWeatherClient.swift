import Foundation

public struct OpenMeteoWeatherClient: WeatherForecastProviding, Sendable {
    public enum ClientError: Error, Equatable, Sendable {
        case insecureEndpoint
        case invalidEndpoint
        case invalidQuery
        case httpStatus(Int)
        case invalidResponse
        case decodingFailed
    }

    public static let defaultGeocodingEndpoint = URL(
        string: "https://geocoding-api.open-meteo.com/v1/search"
    )!
    public static let defaultForecastEndpoint = URL(
        string: "https://api.open-meteo.com/v1/forecast"
    )!

    private let geocodingEndpoint: URL
    private let forecastEndpoint: URL
    private let timeout: TimeInterval
    private let loader: HTTPDataLoader

    public init(
        geocodingEndpoint: URL = OpenMeteoWeatherClient.defaultGeocodingEndpoint,
        forecastEndpoint: URL = OpenMeteoWeatherClient.defaultForecastEndpoint,
        timeout: TimeInterval = 10,
        loader: HTTPDataLoader = .urlSession
    ) throws {
        for endpoint in [geocodingEndpoint, forecastEndpoint] {
            guard endpoint.scheme?.lowercased() == "https" else {
                throw ClientError.insecureEndpoint
            }
            guard endpoint.host != nil else {
                throw ClientError.invalidEndpoint
            }
        }
        guard timeout > 0 else { throw ClientError.invalidEndpoint }

        self.geocodingEndpoint = geocodingEndpoint
        self.forecastEndpoint = forecastEndpoint
        self.timeout = timeout
        self.loader = loader
    }

    public func searchLocations(query: String) async throws -> [WeatherLocation] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw ClientError.invalidQuery }
        let data = try await load(
            endpoint: geocodingEndpoint,
            queryItems: [
                URLQueryItem(name: "name", value: query),
                URLQueryItem(name: "count", value: "10"),
                URLQueryItem(name: "language", value: "en"),
                URLQueryItem(name: "format", value: "json"),
            ]
        )
        do {
            return try JSONDecoder().decode(GeocodingResponse.self, from: data)
                .results.map(WeatherLocation.init)
        } catch {
            throw ClientError.decodingFailed
        }
    }

    public func forecast(for location: WeatherLocation) async throws -> WeatherForecast {
        let data = try await load(
            endpoint: forecastEndpoint,
            queryItems: [
                URLQueryItem(name: "latitude", value: String(location.latitude)),
                URLQueryItem(name: "longitude", value: String(location.longitude)),
                URLQueryItem(name: "hourly", value: "temperature_2m,relative_humidity_2m,precipitation_probability,weather_code"),
                URLQueryItem(name: "timeformat", value: "unixtime"),
                URLQueryItem(name: "timezone", value: "UTC"),
                URLQueryItem(name: "forecast_hours", value: "48"),
            ]
        )
        do {
            let response = try JSONDecoder().decode(ForecastResponse.self, from: data)
            let hourly = response.hourly
            guard
                hourly.time.count == hourly.temperature2m.count,
                hourly.time.count == hourly.relativeHumidity2m.count,
                hourly.time.count == hourly.precipitationProbability.count,
                hourly.time.count == hourly.weatherCode.count
            else {
                throw ClientError.invalidResponse
            }
            return WeatherForecast(location: location, hourly: zip(
                zip(zip(hourly.time, hourly.temperature2m), hourly.relativeHumidity2m),
                zip(hourly.precipitationProbability, hourly.weatherCode)
            ).map { pair in
                WeatherForecastPoint(
                    timestamp: Date(timeIntervalSince1970: pair.0.0.0),
                    temperatureCelsius: pair.0.0.1,
                    relativeHumidity: pair.0.1,
                    precipitationProbability: pair.1.0,
                    weatherCode: pair.1.1
                )
            })
        } catch let error as ClientError {
            throw error
        } catch {
            throw ClientError.decodingFailed
        }
    }

    private func load(endpoint: URL, queryItems: [URLQueryItem]) async throws -> Data {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw ClientError.invalidEndpoint
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw ClientError.invalidEndpoint }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        let response = try await loader.load(request)
        guard (200...299).contains(response.statusCode) else {
            throw ClientError.httpStatus(response.statusCode)
        }
        return response.data
    }
}

private struct GeocodingResponse: Decodable {
    let results: [GeocodingResult]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent([GeocodingResult].self, forKey: .results) ?? []
    }

    private enum CodingKeys: String, CodingKey { case results }
}

private struct GeocodingResult: Decodable {
    let name: String
    let admin1: String?
    let country: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double

    private enum CodingKeys: String, CodingKey {
        case name
        case admin1
        case country
        case countryCode = "country_code"
        case latitude
        case longitude
    }
}

private extension WeatherLocation {
    init(_ result: GeocodingResult) {
        self.init(
            displayName: result.name,
            administrativeArea: result.admin1,
            country: result.country,
            countryCode: result.countryCode,
            latitude: result.latitude,
            longitude: result.longitude
        )
    }
}

private struct ForecastResponse: Decodable {
    let hourly: Hourly

    struct Hourly: Decodable {
        let time: [TimeInterval]
        let temperature2m: [Double]
        let relativeHumidity2m: [Int]
        let precipitationProbability: [Int]
        let weatherCode: [Int]

        private enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case precipitationProbability = "precipitation_probability"
            case weatherCode = "weather_code"
        }
    }
}
