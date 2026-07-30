import Combine
import Foundation

public enum QuickCalTheme: String, CaseIterable, Codable, Sendable {
    case systemLight
    case systemDark
    case swissLight
    case swissDark
    case colorLight
    case colorDark

    public var next: QuickCalTheme {
        switch self {
        case .systemLight:
            .systemDark
        case .systemDark:
            .swissLight
        case .swissLight:
            .swissDark
        case .swissDark:
            .colorLight
        case .colorLight:
            .colorDark
        case .colorDark:
            .systemLight
        }
    }

    public var isDark: Bool {
        switch self {
        case .systemDark, .swissDark, .colorDark:
            true
        case .systemLight, .swissLight, .colorLight:
            false
        }
    }

    public static func systemDefault(isDark: Bool) -> QuickCalTheme {
        isDark ? .systemDark : .systemLight
    }
}

@MainActor
public final class QuickCalThemeStore: ObservableObject {
    public static let defaultKey = "quickCalTheme.v1"

    @Published public private(set) var manualTheme: QuickCalTheme?

    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = QuickCalThemeStore.defaultKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
        manualTheme = userDefaults.string(forKey: key)
            .flatMap(QuickCalTheme.init(rawValue:))
    }

    public func resolvedTheme(systemIsDark: Bool) -> QuickCalTheme {
        manualTheme ?? .systemDefault(isDark: systemIsDark)
    }

    @discardableResult
    public func selectNext(systemIsDark: Bool) -> QuickCalTheme {
        let nextTheme = resolvedTheme(systemIsDark: systemIsDark).next
        manualTheme = nextTheme
        userDefaults.set(nextTheme.rawValue, forKey: key)
        return nextTheme
    }
}
