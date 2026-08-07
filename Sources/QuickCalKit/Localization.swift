import Foundation

public struct QuickCalLocalization: Sendable {
    public enum Key: String, CaseIterable, Sendable {
        case returnToToday = "calendar.return_to_today"
        case previousMonth = "calendar.previous_month"
        case nextMonth = "calendar.next_month"
        case today = "calendar.accessibility.today"
        case selected = "calendar.accessibility.selected"
        case dayOff = "calendar.accessibility.day_off"
        case weekNumberFormat = "calendar.week_number_format"
        case weekNumberShort = "calendar.week_number_short"
        case showWeekNumbers = "settings.show_week_numbers"
        case weekNumbersShort = "settings.week_numbers_short"
        case launchAtLogin = "settings.launch_at_login"
        case launchAtLoginShort = "settings.launch_at_login_short"
        case nextTheme = "settings.next_theme"
        case chooseTheme = "settings.choose_theme"
        case optionsMenu = "settings.options_menu"
        case useSystemAppearance = "settings.use_system_appearance"
        case appearanceLight = "settings.appearance_light"
        case appearanceDark = "settings.appearance_dark"
        case themeSystem = "theme.system"
        case themeSwiss = "theme.swiss"
        case themeColor = "theme.color"
        case themeLedger = "theme.ledger"
        case themePrism = "theme.prism"
        case themeSignalGrid = "theme.signal_grid"
        case themeTitaniumChrono = "theme.titanium_chrono"
        case themeMonochrome = "theme.monochrome"
        case quitQuickCal = "app.quit"
        case launchRequiresApproval = "launch.requires_approval"
        case launchUnknownStatus = "launch.unknown_status"
        case launchChangeFailedFormat = "launch.change_failed_format"
        case dateHeaderFormat = "date.header_format"
        case monthTitleFormat = "date.month_title_format"
        case vacationFutureOne = "vacation.future.one"
        case vacationFutureFew = "vacation.future.few"
        case vacationFutureMany = "vacation.future.many"
        case vacationRemainingOne = "vacation.remaining.one"
        case vacationRemainingFew = "vacation.remaining.few"
        case vacationRemainingMany = "vacation.remaining.many"
        case vacationFinalDay = "vacation.final_day"
        case vacationToday = "vacation.today"
        case weatherVisibility = "weather.visibility"
        case weatherLocation = "weather.location"
        case weatherSearchLocation = "weather.search_location"
        case weatherAutomaticLocation = "weather.automatic_location"
        case weatherLocating = "weather.locating"
        case weatherLocationUnavailable = "weather.location_unavailable"
        case weatherRetryLocation = "weather.retry_location"
        case weatherInterval = "weather.interval"
        case weatherRefresh = "weather.refresh"
        case weatherRefreshing = "weather.refreshing"
        case weatherUnavailable = "weather.unavailable"
        case weatherUpdatedFormat = "weather.updated_format"
        case weatherTemperatureFormat = "weather.temperature_format"
        case weatherHumidityFormat = "weather.humidity_format"
        case weatherPrecipitationFormat = "weather.precipitation_format"
        case weatherPeriodAccessibilityFormat = "weather.period_accessibility_format"
        case marketVisibility = "market.visibility"
        case marketTickers = "market.tickers"
        case marketTickersPlaceholder = "market.tickers_placeholder"
        case marketTickersAccessibilityLabel = "market.tickers_accessibility_label"
        case marketTickersAccessibilityHint = "market.tickers_accessibility_hint"
        case marketFailedTickersFormat = "market.failed_tickers_format"
        case marketFailedTickersAccessibilityFormat = "market.failed_tickers_accessibility_format"
        case marketLoading = "market.loading"
        case marketUnavailable = "market.unavailable"
        case marketEmpty = "market.empty"
        case marketEmptyAccessibility = "market.empty_accessibility"
        case marketStaleFormat = "market.stale_format"
        case marketStaleAccessibilityFormat = "market.stale_accessibility_format"
        case marketPartialFormat = "market.partial_format"
        case marketPartialAccessibilityFormat = "market.partial_accessibility_format"
        case marketRetry = "market.retry"
        case marketRetryAccessibility = "market.retry_accessibility"
        case marketRetryHint = "market.retry_hint"
        case marketErrorAccessibility = "market.error_accessibility"
        case marketDataAsOfFormat = "market.data_as_of_format"
        case marketDataDateAccessibilityFormat = "market.data_date_accessibility_format"
        case marketQuoteAccessibilityFormat = "market.quote_accessibility_format"
        case marketDirectionUp = "market.direction_up"
        case marketDirectionDown = "market.direction_down"
        case marketDirectionUnchanged = "market.direction_unchanged"
    }

    public static var current: QuickCalLocalization {
        QuickCalLocalization()
    }

    public let languageIdentifier: String
    public let locale: Locale

    public init(
        preferredLanguages: [String] = Locale.preferredLanguages,
        systemLocale: Locale = .autoupdatingCurrent
    ) {
        let preferred = Bundle.preferredLocalizations(
            from: Self.supportedLanguageIdentifiers,
            forPreferences: preferredLanguages
        ).first
        let language = preferred.flatMap {
            Self.supportedLanguageIdentifiers.contains($0) ? $0 : nil
        } ?? "en"

        languageIdentifier = language
        locale = Self.locale(
            languageIdentifier: language,
            preservingRegionFrom: systemLocale
        )
    }

    public func string(_ key: Key) -> String {
        let english = Self.localizedBundle(for: "en")
            .localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)

        guard languageIdentifier != "en" else {
            return english
        }

        return Self.localizedBundle(for: languageIdentifier)
            .localizedString(forKey: key.rawValue, value: english, table: nil)
    }

    public func format(_ key: Key, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    public func calendar(from systemCalendar: Calendar = .autoupdatingCurrent) -> Calendar {
        let firstWeekday = systemCalendar.firstWeekday
        let minimumDaysInFirstWeek = systemCalendar.minimumDaysInFirstWeek
        var localized = systemCalendar
        localized.locale = locale
        localized.firstWeekday = firstWeekday
        localized.minimumDaysInFirstWeek = minimumDaysInFirstWeek
        return localized
    }

    private static let supportedLanguageIdentifiers = ["en", "ru"]
    private static let resourceBundleName = "QuickCal_QuickCalKit.bundle"

    private static let resourceBundle: Bundle = {
        if
            let resourceURL = Bundle.main.resourceURL,
            let installedBundle = Bundle(
                url: resourceURL.appendingPathComponent(resourceBundleName)
            )
        {
            return installedBundle
        }
        return .module
    }()

    private static func localizedBundle(for languageIdentifier: String) -> Bundle {
        guard
            let url = resourceBundle.url(
                forResource: languageIdentifier,
                withExtension: "lproj"
            ),
            let bundle = Bundle(url: url)
        else {
            return resourceBundle
        }
        return bundle
    }

    private static func locale(
        languageIdentifier: String,
        preservingRegionFrom systemLocale: Locale
    ) -> Locale {
        guard let region = systemLocale.region?.identifier else {
            return Locale(identifier: languageIdentifier)
        }
        return Locale(identifier: "\(languageIdentifier)_\(region)")
    }
}
