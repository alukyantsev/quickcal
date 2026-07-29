import Combine
import Foundation

@MainActor
public final class SelectedDatesStore: ObservableObject {
    public static let defaultKey = "selectedDates.v1"

    @Published public private(set) var selectedDates: Set<CalendarDate>

    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = SelectedDatesStore.defaultKey
    ) {
        self.userDefaults = userDefaults
        self.key = key

        guard
            let data = userDefaults.data(forKey: key),
            let dates = try? JSONDecoder().decode([CalendarDate].self, from: data)
        else {
            selectedDates = []
            return
        }

        selectedDates = Set(dates)
    }

    public func contains(_ date: CalendarDate) -> Bool {
        selectedDates.contains(date)
    }

    @discardableResult
    public func toggle(_ date: CalendarDate) -> Bool {
        var updatedDates = selectedDates
        let isSelected: Bool

        if updatedDates.remove(date) != nil {
            isSelected = false
        } else {
            updatedDates.insert(date)
            isSelected = true
        }

        selectedDates = updatedDates
        persist()
        return isSelected
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(selectedDates.sorted()) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }
}
