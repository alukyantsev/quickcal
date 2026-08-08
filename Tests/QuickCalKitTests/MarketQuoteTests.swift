import Foundation
import Testing
import QuickCalKit

@Suite
struct MarketQuoteSettingsTests {
    @Test
    func defaultsKeepQuotesDisabledWithTheAgreedEightInstruments() {
        #expect(MarketQuoteSettings() == MarketQuoteSettings(
            isVisible: false,
            tickers: [
                "USDRUBF", "EURRUBF", "EUR/USD", "IMOEX",
                "SP500F", "GLDRUBF", "BRENT", "MOEXBTC",
            ]
        ))
    }

    @Test
    func normalizesAliasesWhitespaceCaseAndDuplicatesWhileKeepingOrder() {
        #expect(MarketQuoteSettings.normalizedTickers(
            from: " usd/rub fut, eur rubf, EUR/USD, imoex, S&P 500, gold/rub fut, br, bitcoin, SBER, usdrubf, sber "
        ) == ["USDRUBF", "EURRUBF", "EUR/USD", "IMOEX", "SP500F", "GLDRUBF", "BRENT", "MOEXBTC", "SBER"])
    }

    @Test
    @MainActor
    func settingsAndCachePersistAcrossStoreRecreation() {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let settings = MarketQuoteSettings(isVisible: true, tickers: ["SBER", "IMOEX"])
        let settingsStore = MarketQuoteSettingsStore(userDefaults: fixture.defaults, key: "settings")
        let snapshot = MarketQuoteSnapshot(
            quotes: [MarketQuote(
                ticker: "SBER", displayName: "SBER", price: 312.4,
                change: 2.1, changePercent: 0.68,
                dataDate: Date(timeIntervalSince1970: 1_767_225_600)
            )]
        )
        let entry = MarketQuoteCacheEntry(snapshot: snapshot, fetchedAt: Date(timeIntervalSince1970: 1_767_225_600))

        settingsStore.update(settings)
        MarketQuoteCacheStore(userDefaults: fixture.defaults, key: "cache").save(entry)

        #expect(MarketQuoteSettingsStore(userDefaults: fixture.defaults, key: "settings").settings == settings)
        #expect(MarketQuoteCacheStore(userDefaults: fixture.defaults, key: "cache").load() == entry)
    }

    @Test
    @MainActor
    func storedPreviousDefaultsMigrateWithoutOverwritingCustomWatchlists() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let oldDefaults = MarketQuoteSettings(isVisible: true, tickers: MarketQuoteSettings.previousDefaultTickers)
        fixture.defaults.set(try JSONEncoder().encode(oldDefaults), forKey: "settings")

        let migrated = MarketQuoteSettingsStore(userDefaults: fixture.defaults, key: "settings")

        #expect(migrated.settings == MarketQuoteSettings(isVisible: true))
        #expect(MarketQuoteSettingsStore(userDefaults: fixture.defaults, key: "settings").settings == MarketQuoteSettings(isVisible: true))
    }

    @Test
    @MainActor
    func storedCustomWatchlistIsNotChangedByDefaultMigration() throws {
        let fixture = defaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let custom = MarketQuoteSettings(isVisible: true, tickers: ["SBER", "IMOEX"])
        fixture.defaults.set(try JSONEncoder().encode(custom), forKey: "settings")

        #expect(MarketQuoteSettingsStore(userDefaults: fixture.defaults, key: "settings").settings == custom)
    }

    @Test
    func cacheRemainsUsableForSevenCalendarDaysAndRejectsAnOlderSnapshot() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fetchedAt = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 12))!
        let entry = MarketQuoteCacheEntry(snapshot: MarketQuoteSnapshot(quotes: []), fetchedAt: fetchedAt)

        #expect(entry.isUsable(at: calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 23))!, calendar: calendar))
        #expect(!entry.isUsable(at: calendar.date(from: DateComponents(year: 2026, month: 8, day: 9))!, calendar: calendar))
    }

    private func defaultsFixture() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "QuickCalTests.MarketQuotes.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

@Suite
struct MOEXISSMarketQuoteProviderTests {
    private actor RequestRecorder {
        private var responses: [HTTPDataResponse]
        private(set) var requests: [URLRequest] = []

        init(responses: [HTTPDataResponse]) { self.responses = responses }

        func load(_ request: URLRequest) -> HTTPDataResponse {
            requests.append(request)
            return responses.removeFirst()
        }
    }

    @Test(arguments: [
        ("USDRUBF", "USD/RUB FUT", "/iss/engines/futures/markets/forts/securities/USDRUBF.json"),
        ("EURRUBF", "EUR/RUB FUT", "/iss/engines/futures/markets/forts/securities/EURRUBF.json"),
        ("SP500F", "S&P 500 FUT", "/iss/engines/futures/markets/forts/securities/SP500F.json"),
        ("GLDRUBF", "GOLD ₽ FUT", "/iss/engines/futures/markets/forts/securities/GLDRUBF.json"),
        ("IMOEX", "IMOEX", "/iss/engines/stock/markets/index/securities/IMOEX.json"),
        ("MOEXBTC", "Bitcoin (MOEX)", "/iss/engines/stock/markets/index/securities/MOEXBTC.json"),
        ("SBER", "SBER", "/iss/engines/stock/markets/shares/boards/TQBR/securities/SBER.json"),
    ])
    func fetchesKnownInstrumentsFromTheirMOEXMarkets(
        ticker: String,
        displayName: String,
        expectedPath: String
    ) async throws {
        let recorder = RequestRecorder(responses: [quoteResponse(
            secid: ticker, shortName: ticker, last: 100.5, previous: 99.5,
            date: "2026-01-01"
        )])
        let provider = try MOEXISSMarketQuoteProvider(loader: HTTPDataLoader { request in
            await recorder.load(request)
        })

        let quote = try await provider.quote(for: ticker)

        #expect(quote == MarketQuote(
            ticker: ticker, displayName: displayName, price: 100.5,
            change: 1, changePercent: 1.01,
            dataDate: try date("2026-01-01")
        ))
        let request = try #require(await recorder.requests.first)
        let url = try #require(request.url)
        #expect(url.scheme == "https")
        #expect(url.host == "iss.moex.com")
        #expect(url.path == expectedPath)
    }

    @Test
    func findsTheActiveEuroDollarContractFromMOEXDataInsteadOfUsingAQuarterCode() async throws {
        let recorder = RequestRecorder(responses: [
            HTTPDataResponse(data: Data("""
            {"securities":{"columns":["SECID","SHORTNAME","ASSETCODE","LASTTRADEDATE"],"data":[["EuU6","EUR/USD Sep 2026","EURUSD","2026-09-17"],["EuM6","EUR/USD Jun 2026","EURUSD","2026-06-18"]]}}
            """.utf8), statusCode: 200),
            quoteResponse(secid: "EuU6", shortName: "EUR/USD Sep 2026", last: 1.125, previous: 1.12, date: "2026-08-08"),
        ])
        let provider = try MOEXISSMarketQuoteProvider(loader: HTTPDataLoader { request in
            await recorder.load(request)
        })

        let quote = try await provider.quote(for: " eur/usd ")

        #expect(quote.ticker == "EUR/USD")
        #expect(quote.displayName == "EUR/USD")
        #expect(quote.price == 1.125)
        #expect(abs(quote.change - 0.005) < 0.000_001)
        #expect(quote.changePercent == 0.45)
        let requests = await recorder.requests
        #expect(requests.count == 2)
        #expect(requests[0].url?.path == "/iss/engines/futures/markets/forts/securities.json")
        #expect(requests[1].url?.path == "/iss/engines/futures/markets/forts/securities/EuU6.json")
    }

    @Test
    func findsTheActiveEuroDollarContractUsingTheCurrentMOEXEDInstrumentCode() async throws {
        let recorder = RequestRecorder(responses: [
            HTTPDataResponse(data: Data("""
            {"securities":{"columns":["SECID","SHORTNAME","ASSETCODE","LASTTRADEDATE"],"data":[["EDU6","ED-9.26","ED","2026-09-17"],["EDM6","ED-6.26","ED","2026-06-18"]]}}
            """.utf8), statusCode: 200),
            HTTPDataResponse(data: Data("""
            {"marketdata":{"columns":["SECID","LAST","LASTTOPREVPRICE","TRADEDATE"],"data":[["EDU6",1.164,0.35,"2026-08-08"]]}}
            """.utf8), statusCode: 200),
        ])
        let provider = try MOEXISSMarketQuoteProvider(loader: HTTPDataLoader { request in
            await recorder.load(request)
        })

        let quote = try await provider.quote(for: "EUR/USD")

        #expect(quote.ticker == "EUR/USD")
        #expect(quote.price == 1.164)
        #expect(quote.changePercent == 0.35)
        #expect(quote.change > 0)
        let requests = await recorder.requests
        #expect(requests[1].url?.path == "/iss/engines/futures/markets/forts/securities/EDU6.json")
    }

    @Test
    func findsTheNearestActiveBrentContractFromMOEXData() async throws {
        let recorder = RequestRecorder(responses: [
            HTTPDataResponse(data: Data("""
            {"securities":{"columns":["SECID","SHORTNAME","ASSETCODE","LASTTRADEDATE"],"data":[["BRU6","BR-9.26","BR","2026-08-31"],["BRV6","BR-10.26","BR","2026-10-01"]]}}
            """.utf8), statusCode: 200),
            quoteResponse(secid: "BRU6", shortName: "BR-9.26", last: 82.7, previous: 82.1, date: "2026-08-08"),
        ])
        let provider = try MOEXISSMarketQuoteProvider(
            loader: HTTPDataLoader { request in await recorder.load(request) },
            now: { try! date("2026-08-08") }
        )

        let quote = try await provider.quote(for: "brent")

        #expect(quote.ticker == "BRENT")
        #expect(quote.displayName == "Brent FUT")
        #expect(quote.price == 82.7)
        let requests = await recorder.requests
        #expect(requests[1].url?.path == "/iss/engines/futures/markets/forts/securities/BRU6.json")
    }

    @Test
    func readsTheIndexPriceAndDailyChangeFromTheMOEXIndexMarketdataFields() async throws {
        let recorder = RequestRecorder(responses: [HTTPDataResponse(data: Data("""
        {"marketdata":{"columns":["SECID","LASTVALUE","CURRENTVALUE","LASTCHANGE","LASTCHANGEPRC","TRADEDATE"],"data":[["IMOEX",2285.88,2281.31,-4.57,-0.2,"2026-08-07"]]}}
        """.utf8), statusCode: 200)])
        let provider = try MOEXISSMarketQuoteProvider(loader: HTTPDataLoader { request in
            await recorder.load(request)
        })

        let quote = try await provider.quote(for: "IMOEX")

        #expect(quote.price == 2281.31)
        #expect(quote.change == -4.57)
        #expect(quote.changePercent == -0.2)
    }

    @Test
    func readsTheBitcoinIndexPriceAndDailyChangeFromMOEXIndexFields() async throws {
        let recorder = RequestRecorder(responses: [HTTPDataResponse(data: Data("""
        {"marketdata":{"columns":["SECID","CURRENTVALUE","LASTCHANGE","LASTCHANGEPRC","TRADEDATE"],"data":[["MOEXBTC",64970.92,310.95,0.48,"2026-08-07"]]}}
        """.utf8), statusCode: 200)])
        let provider = try MOEXISSMarketQuoteProvider(loader: HTTPDataLoader { request in
            await recorder.load(request)
        })

        let quote = try await provider.quote(for: "bitcoin")

        #expect(quote.ticker == "MOEXBTC")
        #expect(quote.displayName == "Bitcoin (MOEX)")
        #expect(quote.price == 64970.92)
        #expect(quote.change == 310.95)
        #expect(quote.changePercent == 0.48)
    }

    @Test
    func usesTheMOEXFuturesDailyPercentInsteadOfTreatingItAsAnAbsoluteChange() async throws {
        let recorder = RequestRecorder(responses: [HTTPDataResponse(data: Data("""
        {"marketdata":{"columns":["SECID","LAST","LASTTOPREVPRICE","TRADEDATE"],"data":[["USDRUBF",82.51,1.02,"2026-08-07"]]}}
        """.utf8), statusCode: 200)])
        let provider = try MOEXISSMarketQuoteProvider(loader: HTTPDataLoader { request in
            await recorder.load(request)
        })

        let quote = try await provider.quote(for: "USDRUBF")

        #expect(quote.changePercent == 1.02)
        #expect(quote.change > 0)
        #expect(abs(quote.change - 0.833) < 0.01)
    }

    @Test
    func keepsBothChangesAtZeroWhenMOEXReportsNoTradesForTheSession() async throws {
        let recorder = RequestRecorder(responses: [HTTPDataResponse(data: Data("""
        {"marketdata":{"columns":["SECID","LAST","PREVPRICE","LASTTOPREVPRICE","LASTCHANGE","LASTCHANGEPRC","NUMTRADES","TRADEDATE"],"data":[["SBER",100,95,1.01,0,1.01,0,"2026-08-08"]]}}
        """.utf8), statusCode: 200)])
        let provider = try MOEXISSMarketQuoteProvider(loader: HTTPDataLoader { request in
            await recorder.load(request)
        })

        let quote = try await provider.quote(for: "SBER")

        #expect(quote.price == 100)
        #expect(quote.change == 0)
        #expect(quote.changePercent == 0)
    }

    @Test
    func retainsDailyMovementWhenMOEXReportsTradesEvenIfLastChangeIsZero() async throws {
        let recorder = RequestRecorder(responses: [HTTPDataResponse(data: Data("""
        {"marketdata":{"columns":["SECID","LAST","LASTTOPREVPRICE","LASTCHANGE","NUMTRADES","TRADEDATE"],"data":[["SBER",100,0.41,0,22577,"2026-08-08"]]}}
        """.utf8), statusCode: 200)])
        let provider = try MOEXISSMarketQuoteProvider(loader: HTTPDataLoader { request in
            await recorder.load(request)
        })

        let quote = try await provider.quote(for: "SBER")

        #expect(quote.changePercent == 0.41)
        #expect(quote.change > 0)
    }

    @Test(arguments: [
        ("TRADEDATE", "2026-08-07"),
        ("TRADE_SESSION_DATE", "2026-08-06"),
        ("SYSTIME", "2026-08-05 19:15:00"),
    ])
    func usesOnlyMarketdataSessionFieldsForTheQuoteDate(
        dateColumn: String,
        value: String
    ) async throws {
        let response = HTTPDataResponse(data: Data("""
        {"marketdata":{"columns":["SECID","LAST","PREVPRICE","\(dateColumn)"],"data":[["SBER",100,99,"\(value)"]]},"securities":{"columns":["SECID","LASTTRADEDATE"],"data":[["SBER","2030-01-01"]]}}
        """.utf8), statusCode: 200)
        let recorder = RequestRecorder(responses: [response])
        let provider = try MOEXISSMarketQuoteProvider(
            loader: HTTPDataLoader { request in await recorder.load(request) },
            now: { Date(timeIntervalSince1970: 0) }
        )

        let quote = try await provider.quote(for: "SBER")

        let expectedDate = try date(String(value.prefix(10)))
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(quote.dataDate.map(utcCalendar.startOfDay(for:)) == expectedDate)
        let requests = await recorder.requests
        let url = try #require(requests.first?.url)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query?.first(where: { $0.name == "iss.only" })?.value == "marketdata")
        #expect(query?.first(where: { $0.name == "marketdata.columns" })?.value?.contains("NUMTRADES") == true)
        #expect(query?.contains(where: { $0.name == "securities.columns" }) == false)
    }

    @Test
    func leavesTheQuoteDateUnavailableWhenMarketdataHasNoSessionDate() async throws {
        let recorder = RequestRecorder(responses: [HTTPDataResponse(data: Data("""
        {"marketdata":{"columns":["SECID","LAST","PREVPRICE"],"data":[["SBER",100,99]]},"securities":{"columns":["SECID","LASTTRADEDATE"],"data":[["SBER","2030-01-01"]]}}
        """.utf8), statusCode: 200)])
        let provider = try MOEXISSMarketQuoteProvider(
            loader: HTTPDataLoader { request in await recorder.load(request) },
            now: { Date(timeIntervalSince1970: 0) }
        )

        #expect(try await provider.quote(for: "SBER").dataDate == nil)
    }

    @Test
    func reportsUnknownAndInsecureSourcesWithoutReturningAQuote() async throws {
        let provider = try MOEXISSMarketQuoteProvider(loader: HTTPDataLoader { _ in
            HTTPDataResponse(data: Data("{\"marketdata\":{\"columns\":[\"SECID\"],\"data\":[]},\"securities\":{\"columns\":[],\"data\":[]}}".utf8), statusCode: 200)
        })
        await #expect(throws: MOEXISSMarketQuoteProvider.ClientError.unknownTicker("UNKNOWN")) {
            try await provider.quote(for: "unknown")
        }
        #expect(throws: MOEXISSMarketQuoteProvider.ClientError.insecureEndpoint) {
            try MOEXISSMarketQuoteProvider(endpoint: URL(string: "http://iss.moex.com/iss")!)
        }
    }

    private func quoteResponse(
        secid: String, shortName: String, last: Double, previous: Double, date: String
    ) -> HTTPDataResponse {
        let percentage = (last - previous) / previous * 100
        return HTTPDataResponse(data: Data("""
        {"marketdata":{"columns":["SECID","LAST","PREVPRICE","LASTTOPREVPRICE","TRADEDATE"],"data":[["\(secid)",\(last),\(previous),\(percentage),"\(date)"]]}}
        """.utf8), statusCode: 200)
    }

    private func date(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return try #require(formatter.date(from: value))
    }
}
