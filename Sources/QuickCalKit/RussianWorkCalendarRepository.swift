import Foundation

public actor RussianWorkCalendarRepository {
    private struct StoredCalendar: Sendable {
        let calendar: RussianWorkCalendar
        let rawData: Data
        let fetchedAt: Date
    }

    private struct Resolution: Sendable {
        let storedCalendar: StoredCalendar?
        let didAttemptRefresh: Bool
    }

    private static let refreshInterval: TimeInterval = 24 * 60 * 60

    private let client: any IsDayOffLoading
    private let cache: any RussianWorkCalendarCaching
    private let now: @Sendable () -> Date
    private let timeZone: TimeZone

    private var memory: [Int: StoredCalendar] = [:]
    private var inFlight: [Int: Task<Resolution, Never>] = [:]
    private var lastRefreshAttempt: [Int: Date] = [:]

    public init(
        client: any IsDayOffLoading,
        cache: any RussianWorkCalendarCaching = RussianWorkCalendarCache(),
        now: @escaping @Sendable () -> Date = { Date() },
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.client = client
        self.cache = cache
        self.now = now
        self.timeZone = timeZone
    }

    public func calendar(for year: Int) async -> RussianWorkCalendar? {
        guard (1...9999).contains(year) else {
            return nil
        }

        if let task = inFlight[year] {
            return await task.value.storedCalendar?.calendar
        }

        let requestDate = now()
        if let previousAttempt = lastRefreshAttempt[year],
           requestDate.timeIntervalSince(previousAttempt) < Self.refreshInterval
        {
            return memory[year]?.calendar
        }

        let memoryEntry = memory[year]
        let task = Task<Resolution, Never> {
            await Self.resolve(
                year: year,
                memoryEntry: memoryEntry,
                client: client,
                cache: cache,
                now: requestDate,
                timeZone: timeZone
            )
        }
        inFlight[year] = task

        let resolution = await task.value
        inFlight[year] = nil
        if resolution.didAttemptRefresh {
            lastRefreshAttempt[year] = requestDate
        }
        if let storedCalendar = resolution.storedCalendar {
            memory[year] = storedCalendar
        }
        return resolution.storedCalendar?.calendar
    }

    public static func fallbackStatus(
        for date: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> WorkdayStatus {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        switch gregorian.component(.weekday, from: date) {
        case 1, 7:
            return .nonWorking
        default:
            return .working
        }
    }

    private static func resolve(
        year: Int,
        memoryEntry: StoredCalendar?,
        client: any IsDayOffLoading,
        cache: any RussianWorkCalendarCaching,
        now: Date,
        timeZone: TimeZone
    ) async -> Resolution {
        var cached = memoryEntry

        if cached == nil {
            do {
                if let diskEntry = try await cache.load(year: year),
                   let parsed = try? RussianWorkCalendar(
                       year: year,
                       rawData: diskEntry.rawData
                   ) {
                    cached = StoredCalendar(
                        calendar: parsed,
                        rawData: diskEntry.rawData,
                        fetchedAt: diskEntry.fetchedAt
                    )
                }
            } catch {
                // A cache miss or read error must not block network fallback.
            }
        }

        if let cached,
           !needsRefresh(
               year: year,
               fetchedAt: cached.fetchedAt,
               now: now,
               timeZone: timeZone
           ) {
            return Resolution(
                storedCalendar: cached,
                didAttemptRefresh: false
            )
        }

        do {
            let rawData = try await client.fetch(year: year)
            let parsed = try RussianWorkCalendar(
                year: year,
                rawData: rawData
            )
            let downloaded = StoredCalendar(
                calendar: parsed,
                rawData: rawData,
                fetchedAt: now
            )
            try? await cache.save(
                rawData: rawData,
                for: year,
                fetchedAt: now
            )
            return Resolution(
                storedCalendar: downloaded,
                didAttemptRefresh: true
            )
        } catch {
            return Resolution(
                storedCalendar: cached,
                didAttemptRefresh: true
            )
        }
    }

    private static func needsRefresh(
        year: Int,
        fetchedAt: Date,
        now: Date,
        timeZone: TimeZone
    ) -> Bool {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let currentYear = gregorian.component(.year, from: now)

        if year < currentYear {
            return false
        }
        return now.timeIntervalSince(fetchedAt) >= refreshInterval
    }
}
