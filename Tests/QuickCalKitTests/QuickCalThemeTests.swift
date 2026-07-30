import Foundation
import Testing
import QuickCalKit

@Suite
@MainActor
struct QuickCalThemeTests {
    @Test
    func themesCycleThroughAllSixOptionsInApprovedOrder() {
        #expect(QuickCalTheme.allCases == [
            .systemLight,
            .systemDark,
            .swissLight,
            .swissDark,
            .colorLight,
            .colorDark,
        ])
        #expect(QuickCalTheme.systemLight.next == .systemDark)
        #expect(QuickCalTheme.systemDark.next == .swissLight)
        #expect(QuickCalTheme.swissLight.next == .swissDark)
        #expect(QuickCalTheme.swissDark.next == .colorLight)
        #expect(QuickCalTheme.colorLight.next == .colorDark)
        #expect(QuickCalTheme.colorDark.next == .systemLight)
    }

    @Test
    func lightAndDarkSemanticsMatchEveryThemePair() {
        #expect(!QuickCalTheme.systemLight.isDark)
        #expect(QuickCalTheme.systemDark.isDark)
        #expect(!QuickCalTheme.swissLight.isDark)
        #expect(QuickCalTheme.swissDark.isDark)
        #expect(!QuickCalTheme.colorLight.isDark)
        #expect(QuickCalTheme.colorDark.isDark)
    }

    @Test
    func missingOrInvalidManualSelectionFollowsSystemAppearance() {
        let fixture = defaultsFixture()
        defer {
            fixture.defaults.removePersistentDomain(
                forName: fixture.suiteName
            )
        }
        let key = "theme.test"
        let store = QuickCalThemeStore(
            userDefaults: fixture.defaults,
            key: key
        )

        #expect(store.resolvedTheme(systemIsDark: false) == .systemLight)
        #expect(store.resolvedTheme(systemIsDark: true) == .systemDark)

        fixture.defaults.set("unknown-theme", forKey: key)
        let restored = QuickCalThemeStore(
            userDefaults: fixture.defaults,
            key: key
        )

        #expect(restored.resolvedTheme(systemIsDark: false) == .systemLight)
        #expect(restored.resolvedTheme(systemIsDark: true) == .systemDark)
    }

    @Test
    func manualSelectionPersistsAndOverridesLaterSystemChanges() {
        let fixture = defaultsFixture()
        defer {
            fixture.defaults.removePersistentDomain(
                forName: fixture.suiteName
            )
        }
        let key = "theme.test"
        let store = QuickCalThemeStore(
            userDefaults: fixture.defaults,
            key: key
        )

        #expect(store.selectNext(systemIsDark: false) == .systemDark)

        let restored = QuickCalThemeStore(
            userDefaults: fixture.defaults,
            key: key
        )

        #expect(restored.manualTheme == .systemDark)
        #expect(restored.resolvedTheme(systemIsDark: false) == .systemDark)
        #expect(restored.resolvedTheme(systemIsDark: true) == .systemDark)
    }

    @Test
    func darkSystemDefaultContinuesFromSystemDarkIntoSwissLight() {
        let fixture = defaultsFixture()
        defer {
            fixture.defaults.removePersistentDomain(
                forName: fixture.suiteName
            )
        }
        let store = QuickCalThemeStore(
            userDefaults: fixture.defaults,
            key: "theme.test"
        )

        #expect(store.selectNext(systemIsDark: true) == .swissLight)
    }

    private func defaultsFixture() -> (
        defaults: UserDefaults,
        suiteName: String
    ) {
        let suiteName = "QuickCalTests.QuickCalTheme.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
