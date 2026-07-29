import Foundation
import Testing
import QuickCalKit

@Suite
struct IsDayOffClientTests {
    private actor RequestRecorder {
        private(set) var requests: [URLRequest] = []
        var response: HTTPDataResponse

        init(response: HTTPDataResponse) {
            self.response = response
        }

        func load(_ request: URLRequest) -> HTTPDataResponse {
            requests.append(request)
            return response
        }
    }

    @Test
    func requestsRussianFiveDayCalendarWithAllRequiredFlags() async throws {
        let recorder = RequestRecorder(response: HTTPDataResponse(
            data: Data("calendar".utf8),
            statusCode: 200
        ))
        let loader = HTTPDataLoader { request in
            await recorder.load(request)
        }
        let client = try IsDayOffClient(loader: loader)

        let result = try await client.fetch(year: 2031)

        #expect(result == Data("calendar".utf8))
        let request = try #require(await recorder.requests.first)
        let url = try #require(request.url)
        let components = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)
        )
        #expect(components.scheme == "https")
        #expect(components.host == "isdayoff.ru")
        #expect(components.path == "/api/getdata")
        #expect(Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value ?? "")
            }
        ) == [
            "year": "2031",
            "cc": "ru",
            "pre": "1",
            "holiday": "1",
        ])
    }

    @Test
    func appliesConfiguredTimeoutToTheURLRequest() async throws {
        let recorder = RequestRecorder(response: HTTPDataResponse(
            data: Data(),
            statusCode: 200
        ))
        let client = try IsDayOffClient(
            timeout: 7.5,
            loader: HTTPDataLoader { request in
                await recorder.load(request)
            }
        )

        _ = try await client.fetch(year: 2025)

        let request = try #require(await recorder.requests.first)
        #expect(request.timeoutInterval == 7.5)
    }

    @Test
    func rejectsAnInsecureEndpointBeforeSendingARequest() {
        #expect(throws: IsDayOffClient.ClientError.insecureEndpoint) {
            try IsDayOffClient(
                endpoint: URL(string: "http://isdayoff.ru/api/getdata")!,
                loader: HTTPDataLoader { _ in
                    Issue.record("Loader must not be called")
                    return HTTPDataResponse(data: Data(), statusCode: 200)
                }
            )
        }
    }

    @Test
    func rejectsNonSuccessHTTPStatusWithoutParsingTheBody() async throws {
        let client = try IsDayOffClient(loader: HTTPDataLoader { _ in
            HTTPDataResponse(
                data: Data("upstream unavailable".utf8),
                statusCode: 503
            )
        })

        await #expect(throws: IsDayOffClient.ClientError.httpStatus(503)) {
            try await client.fetch(year: 2025)
        }
    }

    @Test
    func propagatesTransportErrors() async throws {
        struct Offline: Error, Equatable {}

        let client = try IsDayOffClient(loader: HTTPDataLoader { _ in
            throw Offline()
        })

        await #expect(throws: Offline.self) {
            try await client.fetch(year: 2025)
        }
    }
}
