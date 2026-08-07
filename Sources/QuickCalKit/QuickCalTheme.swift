import Combine
import Foundation

public enum QuickCalThemeFamily: String, CaseIterable, Identifiable, Sendable {
    case system
    case swiss
    case color
    case ledger
    case prism
    case signalGrid
    case titaniumChrono
    case monochrome

    public var id: String { rawValue }

    public var localizationKey: QuickCalLocalization.Key {
        switch self {
        case .system:
            .themeSystem
        case .swiss:
            .themeSwiss
        case .color:
            .themeColor
        case .ledger:
            .themeLedger
        case .prism:
            .themePrism
        case .signalGrid:
            .themeSignalGrid
        case .titaniumChrono:
            .themeTitaniumChrono
        case .monochrome:
            .themeMonochrome
        }
    }
}

public enum QuickCalThemeAppearance: String, CaseIterable, Sendable {
    case light
    case dark
}

public enum QuickCalTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case systemLight
    case systemDark
    case swissLight
    case swissDark
    case colorLight
    case colorDark
    case ledgerLight
    case ledgerDark
    case prismLight
    case prismDark
    case signalGridLight
    case signalGridDark
    case titaniumChronoLight
    case titaniumChronoDark
    case monochromeLight
    case monochromeDark

    public var id: String { rawValue }

    public var family: QuickCalThemeFamily {
        switch self {
        case .systemLight, .systemDark:
            .system
        case .swissLight, .swissDark:
            .swiss
        case .colorLight, .colorDark:
            .color
        case .ledgerLight, .ledgerDark:
            .ledger
        case .prismLight, .prismDark:
            .prism
        case .signalGridLight, .signalGridDark:
            .signalGrid
        case .titaniumChronoLight, .titaniumChronoDark:
            .titaniumChrono
        case .monochromeLight, .monochromeDark:
            .monochrome
        }
    }

    public var appearance: QuickCalThemeAppearance {
        isDark ? .dark : .light
    }

    public var isDark: Bool {
        switch self {
        case .systemDark, .swissDark, .colorDark, .ledgerDark,
                .prismDark, .signalGridDark, .titaniumChronoDark,
                .monochromeDark:
            true
        default:
            false
        }
    }

    public var next: QuickCalTheme {
        guard let index = Self.allCases.firstIndex(of: self) else {
            return .systemLight
        }
        return Self.allCases[(index + 1) % Self.allCases.count]
    }

    public var previous: QuickCalTheme {
        guard let index = Self.allCases.firstIndex(of: self) else {
            return .systemLight
        }
        return Self.allCases[(index - 1 + Self.allCases.count) % Self.allCases.count]
    }

    public static func theme(
        family: QuickCalThemeFamily,
        appearance: QuickCalThemeAppearance
    ) -> QuickCalTheme {
        switch (family, appearance) {
        case (.system, .light): .systemLight
        case (.system, .dark): .systemDark
        case (.swiss, .light): .swissLight
        case (.swiss, .dark): .swissDark
        case (.color, .light): .colorLight
        case (.color, .dark): .colorDark
        case (.ledger, .light): .ledgerLight
        case (.ledger, .dark): .ledgerDark
        case (.prism, .light): .prismLight
        case (.prism, .dark): .prismDark
        case (.signalGrid, .light): .signalGridLight
        case (.signalGrid, .dark): .signalGridDark
        case (.titaniumChrono, .light): .titaniumChronoLight
        case (.titaniumChrono, .dark): .titaniumChronoDark
        case (.monochrome, .light): .monochromeLight
        case (.monochrome, .dark): .monochromeDark
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
    public func select(_ theme: QuickCalTheme) -> QuickCalTheme {
        manualTheme = theme
        userDefaults.set(theme.rawValue, forKey: key)
        return theme
    }

    @discardableResult
    public func selectNext(systemIsDark: Bool) -> QuickCalTheme {
        select(resolvedTheme(systemIsDark: systemIsDark).next)
    }

    public func useSystemAppearance() {
        manualTheme = nil
        userDefaults.removeObject(forKey: key)
    }
}
