import Combine
import Foundation

@MainActor
public final class MenuBarInformationSettingsStore: ObservableObject {
    public static let defaultKey = "menuBarInformation.isEnabled"

    @Published public private(set) var isEnabled: Bool

    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = MenuBarInformationSettingsStore.defaultKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
        isEnabled = userDefaults.object(forKey: key) as? Bool ?? false
    }

    public func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: key)
    }
}
