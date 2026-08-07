import Foundation
import Testing
import QuickCalKit

@Suite
@MainActor
struct QuickCalThemeTests {
    @Test
    func themesCycleThroughAllSixteenOptionsInFamilyPairs() {
        #expect(QuickCalTheme.allCases == [
            .systemLight,
            .systemDark,
            .swissLight,
            .swissDark,
            .colorLight,
            .colorDark,
            .ledgerLight,
            .ledgerDark,
            .prismLight,
            .prismDark,
            .signalGridLight,
            .signalGridDark,
            .titaniumChronoLight,
            .titaniumChronoDark,
            .monochromeLight,
            .monochromeDark,
        ])
        #expect(QuickCalTheme.systemLight.next == .systemDark)
        #expect(QuickCalTheme.colorDark.next == .ledgerLight)
        #expect(QuickCalTheme.monochromeDark.next == .systemLight)
        #expect(QuickCalTheme.systemLight.previous == .monochromeDark)
    }

    @Test
    func lightAndDarkSemanticsMatchEveryThemePair() {
        for family in QuickCalThemeFamily.allCases {
            let light = QuickCalTheme.theme(
                family: family,
                appearance: .light
            )
            let dark = QuickCalTheme.theme(
                family: family,
                appearance: .dark
            )

            #expect(light.family == family)
            #expect(dark.family == family)
            #expect(!light.isDark)
            #expect(dark.isDark)
        }
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
    func explicitSelectionAndSystemAppearanceUpdatePersistence() {
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

        #expect(store.select(.signalGridDark) == .signalGridDark)
        #expect(fixture.defaults.string(forKey: key) == "signalGridDark")

        store.useSystemAppearance()

        #expect(store.manualTheme == nil)
        #expect(fixture.defaults.object(forKey: key) == nil)
        #expect(store.resolvedTheme(systemIsDark: false) == .systemLight)
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
