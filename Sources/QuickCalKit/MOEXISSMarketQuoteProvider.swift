import Foundation

public struct MOEXISSMarketQuoteProvider: MarketQuoteProviding, Sendable {
    public enum ClientError: Error, Equatable, Sendable {
        case insecureEndpoint
        case invalidEndpoint
        case httpStatus(Int)
        case decodingFailed
        case invalidResponse
        case unknownTicker(String)
    }

    public static let defaultEndpoint = URL(string: "https://iss.moex.com/iss")!

    private let endpoint: URL
    private let timeout: TimeInterval
    private let loader: HTTPDataLoader
    private let now: @Sendable () -> Date

    public init(
        endpoint: URL = MOEXISSMarketQuoteProvider.defaultEndpoint,
        timeout: TimeInterval = 10,
        loader: HTTPDataLoader = .urlSession,
        now: @escaping @Sendable () -> Date = { Date() }
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
        self.now = now
    }

    public func quote(for ticker: String) async throws -> MarketQuote {
        let ticker = MarketQuoteSettings.normalizedTicker(ticker)
        if ticker == "EUR/USD" {
            let activeContract = try await activeEuroDollarContract()
            return try await loadQuote(
                exchangeTicker: activeContract.secid,
                requestedTicker: ticker,
                displayName: ticker,
                path: "engines/futures/markets/forts/securities/\(activeContract.secid).json"
            )
        }

        let route = route(for: ticker)
        return try await loadQuote(
            exchangeTicker: ticker,
            requestedTicker: ticker,
            displayName: route.displayName,
            path: route.path
        )
    }

    private func route(for ticker: String) -> (path: String, displayName: String) {
        switch ticker {
        case "USDRUBF":
            ("engines/futures/markets/forts/securities/USDRUBF.json", "USD/RUB FUT")
        case "EURRUBF":
            ("engines/futures/markets/forts/securities/EURRUBF.json", "EUR/RUB FUT")
        case "IMOEX":
            ("engines/stock/markets/index/securities/IMOEX.json", "IMOEX")
        default:
            ("engines/stock/markets/shares/boards/TQBR/securities/\(ticker).json", ticker)
        }
    }

    private func activeEuroDollarContract() async throws -> (secid: String, expiry: Date?) {
        let response = try await load(
            path: "engines/futures/markets/forts/securities.json",
            queryItems: [
                URLQueryItem(name: "iss.meta", value: "off"),
                URLQueryItem(name: "iss.only", value: "securities"),
                URLQueryItem(name: "securities.columns", value: "SECID,SHORTNAME,ASSETCODE,LASTTRADEDATE"),
            ]
        )
        let securities = try response.table(named: "securities")
        let candidates = securities.rows.compactMap { row -> (String, Date?)? in
            guard
                let secid = row.string("SECID"),
                row.string("ASSETCODE")?.uppercased() == "EURUSD" ||
                    row.string("SHORTNAME")?.uppercased().contains("EUR/USD") == true
            else { return nil }
            return (secid, row.date("LASTTRADEDATE"))
        }
        guard !candidates.isEmpty else { throw ClientError.unknownTicker("EUR/USD") }
        let current = now()
        return candidates
            .filter { $0.1.map { $0 >= current } ?? false }
            .min { ($0.1 ?? .distantFuture) < ($1.1 ?? .distantFuture) }
            ?? candidates.max { ($0.1 ?? .distantPast) < ($1.1 ?? .distantPast) }!
    }

    private func loadQuote(
        exchangeTicker: String,
        requestedTicker: String,
        displayName: String,
        path: String
    ) async throws -> MarketQuote {
        let response = try await load(
            path: path,
            queryItems: [
                URLQueryItem(name: "iss.meta", value: "off"),
                URLQueryItem(name: "iss.only", value: "marketdata,securities"),
                URLQueryItem(name: "marketdata.columns", value: "SECID,LAST,PREVPRICE,LASTTOPREVPRICE"),
                URLQueryItem(name: "securities.columns", value: "SECID,SHORTNAME,LASTTRADEDATE"),
            ]
        )
        let marketData = try response.table(named: "marketdata")
        guard let values = marketData.rows.first(where: { $0.string("SECID") == exchangeTicker }) else {
            throw ClientError.unknownTicker(requestedTicker)
        }
        guard let price = values.double("LAST") else {
            throw ClientError.unknownTicker(requestedTicker)
        }
        let previous = values.double("PREVPRICE")
        let change = values.double("LASTTOPREVPRICE") ?? previous.map { price - $0 } ?? 0
        let percentage = previous.flatMap { $0 == 0 ? nil : (price - $0) / $0 * 100 } ?? 0
        let dataDate = try response.table(named: "securities").rows
            .first(where: { $0.string("SECID") == exchangeTicker })?
            .date("LASTTRADEDATE") ?? now()
        return MarketQuote(
            ticker: requestedTicker,
            displayName: displayName,
            price: price,
            change: change,
            changePercent: rounded(percentage),
            dataDate: dataDate
        )
    }

    private func load(path: String, queryItems: [URLQueryItem]) async throws -> ISSResponse {
        let url = endpoint.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ClientError.invalidEndpoint
        }
        components.queryItems = queryItems
        guard let requestURL = components.url else { throw ClientError.invalidEndpoint }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        let response = try await loader.load(request)
        guard (200...299).contains(response.statusCode) else { throw ClientError.httpStatus(response.statusCode) }
        do {
            return try JSONDecoder().decode(ISSResponse.self, from: response.data)
        } catch {
            throw ClientError.decodingFailed
        }
    }

    private func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

private struct ISSResponse: Decodable {
    let tables: [String: ISSTable]

    init(from decoder: Decoder) throws {
        tables = try decoder.singleValueContainer().decode([String: ISSTable].self)
    }

    func table(named name: String) throws -> ISSTable {
        guard let table = tables[name] else { throw MOEXISSMarketQuoteProvider.ClientError.invalidResponse }
        return table
    }
}

private struct ISSTable: Decodable {
    let columns: [String]
    let data: [[ISSValue?]]

    var rows: [ISSRow] {
        data.map { ISSRow(columns: columns, values: $0) }
    }
}

private struct ISSRow {
    let columns: [String]
    let values: [ISSValue?]

    func string(_ column: String) -> String? {
        guard let index = columns.firstIndex(of: column), index < values.count else { return nil }
        return values[index]?.stringValue
    }

    func double(_ column: String) -> Double? {
        guard let index = columns.firstIndex(of: column), index < values.count else { return nil }
        return values[index]?.doubleValue
    }

    func date(_ column: String) -> Date? {
        guard let value = string(column) else { return nil }
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

private enum ISSValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else { throw DecodingError.typeMismatch(ISSValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported ISS value")) }
    }

    var stringValue: String? {
        switch self {
        case .string(let value): value
        case .number(let value): String(value)
        case .bool(let value): String(value)
        }
    }

    var doubleValue: Double? {
        switch self {
        case .string(let value): Double(value)
        case .number(let value): value
        case .bool: nil
        }
    }
}
