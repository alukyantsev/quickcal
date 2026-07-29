import Foundation

public struct HTTPDataResponse: Sendable, Equatable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public struct HTTPDataLoader: Sendable {
    private let operation: @Sendable (URLRequest) async throws -> HTTPDataResponse

    public init(
        operation: @escaping @Sendable (URLRequest) async throws -> HTTPDataResponse
    ) {
        self.operation = operation
    }

    public func load(_ request: URLRequest) async throws -> HTTPDataResponse {
        try await operation(request)
    }

    public static var urlSession: HTTPDataLoader {
        HTTPDataLoader { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw IsDayOffClient.ClientError.nonHTTPResponse
            }
            return HTTPDataResponse(
                data: data,
                statusCode: httpResponse.statusCode
            )
        }
    }
}

public protocol IsDayOffLoading: Sendable {
    func fetch(year: Int) async throws -> Data
}

public struct IsDayOffClient: IsDayOffLoading, Sendable {
    public enum ClientError: Error, Equatable, Sendable {
        case insecureEndpoint
        case invalidEndpoint
        case invalidYear(Int)
        case nonHTTPResponse
        case httpStatus(Int)
    }

    public static let defaultEndpoint = URL(
        string: "https://isdayoff.ru/api/getdata"
    )!

    private let endpoint: URL
    private let timeout: TimeInterval
    private let loader: HTTPDataLoader

    public init(
        endpoint: URL = IsDayOffClient.defaultEndpoint,
        timeout: TimeInterval = 10,
        loader: HTTPDataLoader = .urlSession
    ) throws {
        guard endpoint.scheme?.lowercased() == "https" else {
            throw ClientError.insecureEndpoint
        }
        guard endpoint.host != nil, timeout > 0 else {
            throw ClientError.invalidEndpoint
        }

        self.endpoint = endpoint
        self.timeout = timeout
        self.loader = loader
    }

    public func fetch(year: Int) async throws -> Data {
        guard (1...9999).contains(year) else {
            throw ClientError.invalidYear(year)
        }

        guard var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        ) else {
            throw ClientError.invalidEndpoint
        }
        components.queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "cc", value: "ru"),
            URLQueryItem(name: "pre", value: "1"),
            URLQueryItem(name: "holiday", value: "1"),
        ]
        guard let url = components.url else {
            throw ClientError.invalidEndpoint
        }

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
