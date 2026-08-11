import Combine
import Foundation

public struct SprintLengthOverride: Codable, Equatable, Sendable {
    public let sprintNumber: Int
    public let lengthInDays: Int

    public init(sprintNumber: Int, lengthInDays: Int) {
        self.sprintNumber = sprintNumber
        self.lengthInDays = lengthInDays
    }
}

public struct SprintPause: Codable, Equatable, Sendable {
    public let startDate: CalendarDate
    public let endDate: CalendarDate

    public init(startDate: CalendarDate, endDate: CalendarDate) {
        self.startDate = startDate
        self.endDate = endDate
    }
}

public struct SprintScheduleSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 2
    public static let defaultLengthInDays = 14

    public let version: Int
    public let isVisible: Bool
    public let startDate: CalendarDate?
    public let firstSprintNumber: Int
    public let defaultLengthInDays: Int
    public let lengthOverrides: [SprintLengthOverride]
    public let pauses: [SprintPause]

    public init(
        isVisible: Bool = false,
        startDate: CalendarDate? = nil,
        firstSprintNumber: Int = 1,
        defaultLengthInDays: Int = SprintScheduleSettings.defaultLengthInDays,
        lengthOverrides: [SprintLengthOverride] = [],
        pauses: [SprintPause] = []
    ) {
        version = Self.currentVersion
        self.isVisible = isVisible
        self.startDate = startDate
        self.firstSprintNumber = firstSprintNumber
        self.defaultLengthInDays = defaultLengthInDays
        self.lengthOverrides = lengthOverrides
        self.pauses = pauses
    }

    public var schedule: SprintSchedule? {
        guard isVisible, let startDate else { return nil }
        return SprintSchedule(
            startDate: startDate,
            firstSprintNumber: firstSprintNumber,
            defaultLengthInDays: defaultLengthInDays,
            lengthOverrides: lengthOverrides,
            pauses: pauses
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        let isVisible = try container.decode(Bool.self, forKey: .isVisible)
        let startDate = try container.decodeIfPresent(CalendarDate.self, forKey: .startDate)
        let firstSprintNumber = try container.decode(Int.self, forKey: .firstSprintNumber)
        let defaultLengthInDays = try container.decode(Int.self, forKey: .defaultLengthInDays)
        let lengthOverrides = version == 1 ? [] : try container.decodeIfPresent(
            [SprintLengthOverride].self,
            forKey: .lengthOverrides
        ) ?? []
        let pauses = version == 1 ? [] : try container.decodeIfPresent(
            [SprintPause].self,
            forKey: .pauses
        ) ?? []

        guard
            version == 1 || version == Self.currentVersion,
            firstSprintNumber > 0,
            defaultLengthInDays > 0,
            !isVisible || startDate != nil,
            areValidSprintRules(
                firstSprintNumber: firstSprintNumber,
                lengthOverrides: lengthOverrides,
                pauses: pauses
            )
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Unsupported or invalid sprint schedule settings."
            )
        }

        self.version = Self.currentVersion
        self.isVisible = isVisible
        self.startDate = startDate
        self.firstSprintNumber = firstSprintNumber
        self.defaultLengthInDays = defaultLengthInDays
        self.lengthOverrides = lengthOverrides.sorted { $0.sprintNumber < $1.sprintNumber }
        self.pauses = pauses.sorted { $0.startDate < $1.startDate }
    }

}

private func areValidSprintRules(
    firstSprintNumber: Int,
    lengthOverrides: [SprintLengthOverride],
    pauses: [SprintPause]
) -> Bool {
    guard lengthOverrides.allSatisfy({
        $0.sprintNumber >= firstSprintNumber && $0.lengthInDays > 0
    }) else { return false }
    guard Set(lengthOverrides.map(\.sprintNumber)).count == lengthOverrides.count else {
        return false
    }

    let sortedPauses = pauses.sorted { $0.startDate < $1.startDate }
    guard sortedPauses.allSatisfy({ $0.startDate <= $0.endDate }) else { return false }
    return zip(sortedPauses, sortedPauses.dropFirst()).allSatisfy {
        $0.endDate < $1.startDate
    }
}

public struct SprintSchedule: Sendable {
    public struct Sprint: Equatable, Sendable {
        public let number: Int
        public let startDate: CalendarDate
        public let endDate: CalendarDate
    }

    public let startDate: CalendarDate
    public let firstSprintNumber: Int
    public let defaultLengthInDays: Int
    public let lengthOverrides: [SprintLengthOverride]
    public let pauses: [SprintPause]
    public let timeZone: TimeZone

    public init?(
        startDate: CalendarDate,
        firstSprintNumber: Int,
        defaultLengthInDays: Int = SprintScheduleSettings.defaultLengthInDays,
        lengthOverrides: [SprintLengthOverride] = [],
        pauses: [SprintPause] = [],
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        guard
            firstSprintNumber > 0,
            defaultLengthInDays > 0,
            areValidSprintRules(
                firstSprintNumber: firstSprintNumber,
                lengthOverrides: lengthOverrides,
                pauses: pauses
            )
        else { return nil }

        self.startDate = startDate
        self.firstSprintNumber = firstSprintNumber
        self.defaultLengthInDays = defaultLengthInDays
        self.lengthOverrides = lengthOverrides.sorted { $0.sprintNumber < $1.sprintNumber }
        self.pauses = pauses.sorted { $0.startDate < $1.startDate }
        self.timeZone = timeZone
    }

    public func sprint(for date: Date) -> Sprint? {
        let calendar = gregorianCalendar
        guard
            let scheduleStart = startDate.date(in: timeZone),
            let requestedDay = CalendarDate(date: date, timeZone: timeZone)?.date(in: timeZone),
            requestedDay >= scheduleStart
        else { return nil }

        var currentStart = scheduleStart
        var number = firstSprintNumber
        var pauseIndex = 0

        while pauseIndex < pauses.count,
              let pauseEnd = pauses[pauseIndex].endDate.date(in: timeZone),
              pauseEnd < currentStart {
            pauseIndex += 1
        }

        for _ in 0..<10_000 {
            if pauseIndex < pauses.count,
               let pauseStart = pauses[pauseIndex].startDate.date(in: timeZone),
               let pauseEnd = pauses[pauseIndex].endDate.date(in: timeZone),
               pauseStart <= currentStart {
                guard let nextStart = calendar.date(byAdding: .day, value: 1, to: pauseEnd) else {
                    return nil
                }
                currentStart = nextStart
                pauseIndex += 1
                continue
            }

            let length = lengthOverrides.first(where: { $0.sprintNumber == number })?.lengthInDays
                ?? defaultLengthInDays
            guard let nominalEnd = calendar.date(byAdding: .day, value: length - 1, to: currentStart) else {
                return nil
            }

            let nextPause = pauseIndex < pauses.count ? pauses[pauseIndex] : nil
            let pauseStart = nextPause?.startDate.date(in: timeZone)
            let end = pauseStart.map { min(nominalEnd, calendar.date(byAdding: .day, value: -1, to: $0)!) }
                ?? nominalEnd

            if requestedDay >= currentStart, requestedDay <= end,
               let sprintStart = CalendarDate(date: currentStart, timeZone: timeZone),
               let sprintEnd = CalendarDate(date: end, timeZone: timeZone) {
                return Sprint(number: number, startDate: sprintStart, endDate: sprintEnd)
            }
            if requestedDay <= end { return nil }

            if let pauseStart, pauseStart <= nominalEnd,
               let pauseEnd = nextPause?.endDate.date(in: timeZone),
               let nextStart = calendar.date(byAdding: .day, value: 1, to: pauseEnd) {
                currentStart = nextStart
                pauseIndex += 1
            } else if let nextStart = calendar.date(byAdding: .day, value: 1, to: nominalEnd) {
                currentStart = nextStart
            } else {
                return nil
            }
            number += 1
        }
        return nil
    }

    public func sprintNumbers(for dates: [Date]) -> [Int] {
        dates.compactMap { sprint(for: $0)?.number }.reduce(into: [Int]()) { result, number in
            if result.last != number { result.append(number) }
        }
    }

    public func sprint(number targetNumber: Int) -> Sprint? {
        guard targetNumber >= firstSprintNumber,
              let initialDate = startDate.date(in: timeZone) else { return nil }
        var cursor = initialDate

        for _ in 0..<10_000 {
            if let sprint = sprint(for: cursor) {
                if sprint.number == targetNumber { return sprint }
                if sprint.number > targetNumber { return nil }
                guard let nextDay = sprint.endDate.date(in: timeZone).flatMap({
                    gregorianCalendar.date(byAdding: .day, value: 1, to: $0)
                }) else { return nil }
                cursor = nextDay
            } else {
                guard let nextDay = gregorianCalendar.date(byAdding: .day, value: 1, to: cursor) else {
                    return nil
                }
                cursor = nextDay
            }
        }
        return nil
    }

    private var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}

@MainActor
public final class SprintScheduleSettingsStore: ObservableObject {
    public static let defaultKey = "sprintScheduleSettings.v1"

    @Published public private(set) var settings: SprintScheduleSettings

    private let userDefaults: UserDefaults
    private let key: String

    public init(userDefaults: UserDefaults = .standard, key: String = SprintScheduleSettingsStore.defaultKey) {
        self.userDefaults = userDefaults
        self.key = key
        settings = (try? userDefaults.data(forKey: key).flatMap {
            try JSONDecoder().decode(SprintScheduleSettings.self, from: $0)
        }) ?? SprintScheduleSettings()
    }

    public func configure(startDate: CalendarDate, firstSprintNumber: Int) {
        guard firstSprintNumber > 0 else { return }
        settings = SprintScheduleSettings(
            isVisible: true,
            startDate: startDate,
            firstSprintNumber: firstSprintNumber,
            defaultLengthInDays: settings.defaultLengthInDays,
            lengthOverrides: settings.lengthOverrides.filter {
                $0.sprintNumber >= firstSprintNumber
            },
            pauses: settings.pauses
        )
        persist()
    }

    public func setVisibility(_ isVisible: Bool) {
        guard settings.startDate != nil else { return }
        replaceSettings(isVisible: isVisible)
    }

    @discardableResult
    public func setLength(ofSprint sprintNumber: Int, to lengthInDays: Int) -> Bool {
        guard lengthInDays > 0, sprintNumber >= settings.firstSprintNumber else { return false }
        var overrides = settings.lengthOverrides.filter { $0.sprintNumber != sprintNumber }
        if lengthInDays != settings.defaultLengthInDays {
            overrides.append(.init(sprintNumber: sprintNumber, lengthInDays: lengthInDays))
        }
        guard areValidSprintRules(
            firstSprintNumber: settings.firstSprintNumber,
            lengthOverrides: overrides,
            pauses: settings.pauses
        ) else { return false }
        replaceSettings(lengthOverrides: overrides.sorted { $0.sprintNumber < $1.sprintNumber })
        return true
    }

    @discardableResult
    public func addPause(from startDate: CalendarDate, through endDate: CalendarDate) -> Bool {
        let pauses = settings.pauses + [.init(startDate: startDate, endDate: endDate)]
        guard areValidSprintRules(
            firstSprintNumber: settings.firstSprintNumber,
            lengthOverrides: settings.lengthOverrides,
            pauses: pauses
        ) else { return false }
        replaceSettings(pauses: pauses.sorted { $0.startDate < $1.startDate })
        return true
    }

    private func replaceSettings(
        isVisible: Bool? = nil,
        lengthOverrides: [SprintLengthOverride]? = nil,
        pauses: [SprintPause]? = nil
    ) {
        settings = SprintScheduleSettings(
            isVisible: isVisible ?? settings.isVisible,
            startDate: settings.startDate,
            firstSprintNumber: settings.firstSprintNumber,
            defaultLengthInDays: settings.defaultLengthInDays,
            lengthOverrides: lengthOverrides ?? settings.lengthOverrides,
            pauses: pauses ?? settings.pauses
        )
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: key)
    }
}
