import Foundation
import Testing
@testable import QuickCal
import QuickCalKit

@Suite(.serialized)
struct WorkCalendarControllerTests {
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

    private actor SequencedClient: IsDayOffLoading {
        private var responses: [Data]

        init(responses: [Data]) {
            self.responses = responses
        }

        func fetch(year: Int) async throws -> Data {
            responses.removeFirst()
        }
    }

    private func rawData(firstCode: UInt8) -> Data {
        var bytes = [UInt8](
            repeating: Character("0").asciiValue!,
            count: 365
        )
        bytes[0] = firstCode
        return Data(bytes)
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

    @Test(arguments: [2026, 2027])
    @MainActor
    func repeatedMonthLoadLetsRepositoryRefreshLoadedCurrentOrFutureYear(
        displayedYear: Int
    ) async throws {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let clock = TestClock(now: date(2026, 7, 29))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "quickcal-controller-tests-\(UUID().uuidString)",
                isDirectory: true
            )
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = SequencedClient(responses: [
            rawData(firstCode: Character("0").asciiValue!),
            rawData(firstCode: Character("8").asciiValue!),
        ])
        let repository = RussianWorkCalendarRepository(
            client: client,
            cache: RussianWorkCalendarCache(directory: directory),
            now: { clock.now() },
            timeZone: timeZone
        )
        let controller = WorkCalendarController(
            repository: repository,
            timeZone: timeZone,
            now: { clock.now() }
        )
        let month = try #require(CalendarMonth(
            containing: date(displayedYear, 7, 1),
            calendar: {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                return calendar
            }()
        ))
        let januaryFirst = date(displayedYear, 1, 1)

        await controller.load(month: month)
        #expect(controller.status(for: januaryFirst) == .working)

        clock.advance(by: 24 * 60 * 60)
        await controller.load(month: month)

        #expect(controller.status(for: januaryFirst) == .nonWorking)
    }
}
