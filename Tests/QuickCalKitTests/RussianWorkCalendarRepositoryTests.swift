import Foundation
import Testing
import QuickCalKit

@Suite(.serialized)
struct RussianWorkCalendarRepositoryTests {
    private enum TestFailure: Error {
        case offline
    }

    private actor SequencedClient: IsDayOffLoading {
        enum Outcome: Sendable {
            case data(Data)
            case failure
        }

        private var outcomes: [Outcome]
        private(set) var requestedYears: [Int] = []

        init(_ outcomes: [Outcome]) {
            self.outcomes = outcomes
        }

        func fetch(year: Int) async throws -> Data {
            requestedYears.append(year)
            guard !outcomes.isEmpty else {
                throw TestFailure.offline
            }
            switch outcomes.removeFirst() {
            case .data(let data):
                return data
            case .failure:
                throw TestFailure.offline
            }
        }
    }

    private actor AsyncGate {
        private var isOpen = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            guard !isOpen else {
                return
            }
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        func open() {
            isOpen = true
            let pending = waiters
            waiters.removeAll()
            pending.forEach { $0.resume() }
        }
    }

    private actor BlockingClient: IsDayOffLoading {
        private let data: Data
        private let gate: AsyncGate
        private(set) var callCount = 0

        init(data: Data, gate: AsyncGate) {
            self.data = data
            self.gate = gate
        }

        func fetch(year: Int) async throws -> Data {
            callCount += 1
            await gate.wait()
            return data
        }
    }

    private final class TestClock: @unchecked Sendable {
        private let lock = NSLock()
        private var storedNow: Date

        init(now: Date) {
            storedNow = now
        }

        func now() -> Date {
            lock.withLock { storedNow }
        }

        func advance(by interval: TimeInterval) {
            lock.withLock {
                storedNow = storedNow.addingTimeInterval(interval)
            }
        }
    }

    private func rawData(firstCode: UInt8 = Character("0").asciiValue!) -> Data {
        var bytes = [UInt8](
            repeating: Character("0").asciiValue!,
            count: 365
        )
        bytes[0] = firstCode
        return Data(bytes)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "quickcal-work-calendar-tests-\(UUID().uuidString)",
                isDirectory: true
            )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int
    ) -> Date {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        return gregorian.date(from: DateComponents(
            timeZone: gregorian.timeZone,
            year: year,
            month: month,
            day: day
        ))!
    }

    @Test
    func diskCacheRoundTripsRawBytesAndFetchTimestamp() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = RussianWorkCalendarCache(directory: directory)
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let rawData = Data([0, 1, 2, 8, 255])

        try await cache.save(
            rawData: rawData,
            for: 2025,
            fetchedAt: fetchedAt
        )
        let entry = try #require(try await cache.load(year: 2025))

        #expect(entry.rawData == rawData)
        #expect(abs(entry.fetchedAt.timeIntervalSince(fetchedAt)) < 1)
    }

    @Test
    func atomicCacheSaveCanReplaceAReadOnlyPreviousFile() async throws {
        let directory = temporaryDirectory()
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: directory.appendingPathComponent("2025.txt").path
            )
            try? FileManager.default.removeItem(at: directory)
        }
        let cache = RussianWorkCalendarCache(directory: directory)

        try await cache.save(
            rawData: Data("old".utf8),
            for: 2025,
            fetchedAt: Date(timeIntervalSince1970: 100)
        )
        let file = directory.appendingPathComponent("2025.txt")
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o444],
            ofItemAtPath: file.path
        )

        try await cache.save(
            rawData: Data("new".utf8),
            for: 2025,
            fetchedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(try Data(contentsOf: file) == Data("new".utf8))
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: directory.path)
                == ["2025.txt"]
        )
    }

    @Test
    func freshCurrentYearDiskCacheAvoidsNetwork() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = date(2026, 7, 29)
        let cache = RussianWorkCalendarCache(directory: directory)
        try await cache.save(
            rawData: rawData(firstCode: Character("8").asciiValue!),
            for: 2026,
            fetchedAt: now.addingTimeInterval(-3_600)
        )
        let client = SequencedClient([.failure])
        let repository = RussianWorkCalendarRepository(
            client: client,
            cache: cache,
            now: { now },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let calendar = try #require(await repository.calendar(for: 2026))

        #expect(calendar.code(month: 1, day: 1) == .holiday)
        #expect(await client.requestedYears.isEmpty)
    }

    @Test
    func staleCurrentYearCacheSurvivesRefreshFailure() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = date(2026, 7, 29)
        let cache = RussianWorkCalendarCache(directory: directory)
        try await cache.save(
            rawData: rawData(firstCode: Character("1").asciiValue!),
            for: 2026,
            fetchedAt: now.addingTimeInterval(-90_000)
        )
        let client = SequencedClient([.failure])
        let repository = RussianWorkCalendarRepository(
            client: client,
            cache: cache,
            now: { now },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let calendar = try #require(await repository.calendar(for: 2026))

        #expect(calendar.code(month: 1, day: 1) == .dayOff)
        #expect(await client.requestedYears == [2026])
    }

    @Test
    func staleCacheThrottlesRepeatedRefreshFailuresForOneDay() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = date(2026, 7, 29)
        let cache = RussianWorkCalendarCache(directory: directory)
        try await cache.save(
            rawData: rawData(firstCode: Character("1").asciiValue!),
            for: 2026,
            fetchedAt: now.addingTimeInterval(-90_000)
        )
        let client = SequencedClient([.failure, .failure])
        let repository = RussianWorkCalendarRepository(
            client: client,
            cache: cache,
            now: { now },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let first = try #require(await repository.calendar(for: 2026))
        let second = try #require(await repository.calendar(for: 2026))

        #expect(first.code(month: 1, day: 1) == .dayOff)
        #expect(second.code(month: 1, day: 1) == .dayOff)
        #expect(await client.requestedYears == [2026])
    }

    @Test
    func completedYearUsesValidStaleCacheWithoutRefresh() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = date(2026, 7, 29)
        let cache = RussianWorkCalendarCache(directory: directory)
        try await cache.save(
            rawData: rawData(),
            for: 2025,
            fetchedAt: now.addingTimeInterval(-40_000_000)
        )
        let client = SequencedClient([.failure])
        let repository = RussianWorkCalendarRepository(
            client: client,
            cache: cache,
            now: { now },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        #expect(await repository.calendar(for: 2025) != nil)
        #expect(await client.requestedYears.isEmpty)
    }

    @Test
    func successfulResponseIsCachedAndThenServedFromMemory() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = date(2026, 7, 29)
        let cache = RussianWorkCalendarCache(directory: directory)
        let client = SequencedClient([
            .data(rawData(firstCode: Character("8").asciiValue!)),
            .failure,
        ])
        let repository = RussianWorkCalendarRepository(
            client: client,
            cache: cache,
            now: { now },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let first = await repository.calendar(for: 2026)
        let second = await repository.calendar(for: 2026)
        let diskEntry = try await cache.load(year: 2026)

        #expect(first == second)
        #expect(first?.code(month: 1, day: 1) == .holiday)
        #expect(await client.requestedYears == [2026])
        #expect(diskEntry?.rawData == rawData(
            firstCode: Character("8").asciiValue!
        ))
    }

    @Test
    func parseFailureWithoutCacheIsRetriedOnlyAfterOneDay() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = TestClock(now: date(2026, 7, 29))
        let client = SequencedClient([
            .data(Data("199".utf8)),
            .data(rawData(firstCode: Character("8").asciiValue!)),
        ])
        let repository = RussianWorkCalendarRepository(
            client: client,
            cache: RussianWorkCalendarCache(directory: directory),
            now: { clock.now() },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let unsupported = await repository.calendar(for: 2031)
        clock.advance(by: 23 * 60 * 60)
        let throttled = await repository.calendar(for: 2031)
        clock.advance(by: 60 * 60)
        let laterAvailable = await repository.calendar(for: 2031)

        #expect(unsupported == nil)
        #expect(throttled == nil)
        #expect(laterAvailable?.code(month: 1, day: 1) == .holiday)
        #expect(await client.requestedYears == [2031, 2031])
    }

    @Test
    func networkFailureWithoutCacheIsRetriedOnlyAfterOneDay() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = TestClock(now: date(2026, 7, 29))
        let client = SequencedClient([
            .failure,
            .data(rawData(firstCode: Character("8").asciiValue!)),
        ])
        let repository = RussianWorkCalendarRepository(
            client: client,
            cache: RussianWorkCalendarCache(directory: directory),
            now: { clock.now() },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let unavailable = await repository.calendar(for: 2031)
        clock.advance(by: 23 * 60 * 60)
        let throttled = await repository.calendar(for: 2031)
        clock.advance(by: 60 * 60)
        let laterAvailable = await repository.calendar(for: 2031)

        #expect(unavailable == nil)
        #expect(throttled == nil)
        #expect(laterAvailable?.code(month: 1, day: 1) == .holiday)
        #expect(await client.requestedYears == [2031, 2031])
    }

    @Test
    func freshDiskCacheReadDoesNotDelayRefreshWhenItBecomesStale() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = TestClock(now: date(2026, 7, 29))
        let cache = RussianWorkCalendarCache(directory: directory)
        try await cache.save(
            rawData: rawData(firstCode: Character("1").asciiValue!),
            for: 2026,
            fetchedAt: clock.now().addingTimeInterval(-23 * 60 * 60)
        )
        let client = SequencedClient([
            .data(rawData(firstCode: Character("8").asciiValue!)),
        ])
        let repository = RussianWorkCalendarRepository(
            client: client,
            cache: cache,
            now: { clock.now() },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let freshDisk = try #require(await repository.calendar(for: 2026))
        clock.advance(by: 2 * 60 * 60)
        let refreshed = try #require(await repository.calendar(for: 2026))

        #expect(freshDisk.code(month: 1, day: 1) == .dayOff)
        #expect(refreshed.code(month: 1, day: 1) == .holiday)
        #expect(await client.requestedYears == [2026])
    }

    @Test
    func concurrentRequestsForOneYearShareOneInFlightFetch() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = AsyncGate()
        let client = BlockingClient(data: rawData(), gate: gate)
        let now = date(2026, 7, 29)
        let repository = RussianWorkCalendarRepository(
            client: client,
            cache: RussianWorkCalendarCache(directory: directory),
            now: { now },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        async let first = repository.calendar(for: 2026)
        async let second = repository.calendar(for: 2026)

        while await client.callCount == 0 {
            await Task.yield()
        }
        #expect(await client.callCount == 1)
        await gate.open()

        let results = await [first, second]
        #expect(results.allSatisfy { $0 != nil })
        #expect(await client.callCount == 1)
    }

    @Test
    func fallbackUsesGregorianSaturdayAndSundayOnly() {
        let timeZone = TimeZone(secondsFromGMT: 0)!

        #expect(RussianWorkCalendarRepository.fallbackStatus(
            for: date(2026, 8, 1),
            timeZone: timeZone
        ) == .nonWorking)
        #expect(RussianWorkCalendarRepository.fallbackStatus(
            for: date(2026, 8, 2),
            timeZone: timeZone
        ) == .nonWorking)
        #expect(RussianWorkCalendarRepository.fallbackStatus(
            for: date(2026, 8, 3),
            timeZone: timeZone
        ) == .working)
    }
}
