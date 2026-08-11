import Combine
import Foundation

public struct SprintScheduleSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let defaultLengthInDays = 14

    public let version: Int
    public let isVisible: Bool
    public let startDate: CalendarDate?
    public let firstSprintNumber: Int
    public let defaultLengthInDays: Int

    public init(
        isVisible: Bool = false,
        startDate: CalendarDate? = nil,
        firstSprintNumber: Int = 1,
        defaultLengthInDays: Int = SprintScheduleSettings.defaultLengthInDays
    ) {
        self.version = Self.currentVersion
        self.isVisible = isVisible
        self.startDate = startDate
        self.firstSprintNumber = firstSprintNumber
        self.defaultLengthInDays = defaultLengthInDays
    }

    public var schedule: SprintSchedule? {
        guard isVisible, let startDate else { return nil }
        return SprintSchedule(
            startDate: startDate,
            firstSprintNumber: firstSprintNumber
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        let isVisible = try container.decode(Bool.self, forKey: .isVisible)
        let startDate = try container.decodeIfPresent(CalendarDate.self, forKey: .startDate)
        let firstSprintNumber = try container.decode(Int.self, forKey: .firstSprintNumber)
        let defaultLengthInDays = try container.decode(Int.self, forKey: .defaultLengthInDays)

        guard
            version == Self.currentVersion,
            firstSprintNumber > 0,
            defaultLengthInDays == Self.defaultLengthInDays,
            !isVisible || startDate != nil
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Unsupported or invalid sprint schedule settings."
            )
        }

        self.version = version
        self.isVisible = isVisible
        self.startDate = startDate
        self.firstSprintNumber = firstSprintNumber
        self.defaultLengthInDays = defaultLengthInDays
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
    public let timeZone: TimeZone

    public init?(
        startDate: CalendarDate,
        firstSprintNumber: Int,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        guard firstSprintNumber > 0 else { return nil }
        self.startDate = startDate
        self.firstSprintNumber = firstSprintNumber
        self.timeZone = timeZone
    }

    public func sprint(for date: Date) -> Sprint? {
        let calendar = gregorianCalendar
        guard
            let start = startDate.date(in: timeZone),
            let day = CalendarDate(date: date, timeZone: timeZone),
            let dayDate = day.date(in: timeZone)
        else { return nil }

        let dayOffset = calendar.dateComponents([.day], from: start, to: dayDate).day ?? 0
        guard dayOffset >= 0 else { return nil }

        let sprintOffset = dayOffset / SprintScheduleSettings.defaultLengthInDays
        guard
            let sprintStart = calendar.date(
                byAdding: .day,
                value: sprintOffset * SprintScheduleSettings.defaultLengthInDays,
                to: start
            ),
            let sprintEnd = calendar.date(
                byAdding: .day,
                value: (sprintOffset + 1) * SprintScheduleSettings.defaultLengthInDays - 1,
                to: start
            ),
            let sprintStartDate = CalendarDate(date: sprintStart, timeZone: timeZone),
            let sprintEndDate = CalendarDate(date: sprintEnd, timeZone: timeZone)
        else { return nil }

        return Sprint(
            number: firstSprintNumber + sprintOffset,
            startDate: sprintStartDate,
            endDate: sprintEndDate
        )
    }

    public func sprintNumbers(for dates: [Date]) -> [Int] {
        let numbers = dates.compactMap { sprint(for: $0)?.number }
        return numbers.reduce(into: [Int]()) { result, number in
            if result.last != number {
                result.append(number)
            }
        }
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

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = SprintScheduleSettingsStore.defaultKey
    ) {
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
            firstSprintNumber: firstSprintNumber
        )
        persist()
    }

    public func setVisibility(_ isVisible: Bool) {
        guard settings.startDate != nil else { return }
        settings = SprintScheduleSettings(
            isVisible: isVisible,
            startDate: settings.startDate,
            firstSprintNumber: settings.firstSprintNumber
        )
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: key)
    }
}
