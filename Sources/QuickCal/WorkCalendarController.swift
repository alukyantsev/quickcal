import Combine
import Foundation
import QuickCalKit

@MainActor
final class WorkCalendarController: ObservableObject {
    @Published private var calendars: [Int: RussianWorkCalendar] = [:]

    private let repository: RussianWorkCalendarRepository?
    private let timeZone: TimeZone
    private var loadingYears: Set<Int> = []

    init(
        repository: RussianWorkCalendarRepository? = nil,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.timeZone = timeZone

        if let repository {
            self.repository = repository
        } else if let client = try? IsDayOffClient() {
            self.repository = RussianWorkCalendarRepository(
                client: client,
                timeZone: timeZone
            )
        } else {
            self.repository = nil
        }
    }

    func load(month: CalendarMonth) async {
        guard let repository else {
            return
        }

        let years = Set(month.weeks.flatMap(\.days).compactMap {
            CalendarDate(date: $0.date, timeZone: timeZone)?.year
        })
        let pendingYears = years.filter {
            calendars[$0] == nil && !loadingYears.contains($0)
        }
        guard !pendingYears.isEmpty else {
            return
        }

        loadingYears.formUnion(pendingYears)
        defer { loadingYears.subtract(pendingYears) }

        await withTaskGroup(
            of: (Int, RussianWorkCalendar?).self
        ) { group in
            for year in pendingYears {
                group.addTask {
                    (year, await repository.calendar(for: year))
                }
            }

            for await (year, calendar) in group {
                if let calendar {
                    calendars[year] = calendar
                }
            }
        }
    }

    func status(for date: Date) -> WorkdayStatus {
        if
            let year = CalendarDate(
                date: date,
                timeZone: timeZone
            )?.year,
            let calendar = calendars[year],
            let status = calendar.status(
                for: date,
                timeZone: timeZone
            )
        {
            return status
        }

        return RussianWorkCalendarRepository.fallbackStatus(
            for: date,
            timeZone: timeZone
        )
    }
}
