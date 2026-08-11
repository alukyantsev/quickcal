import Foundation
import Testing
@testable import QuickCalKit

@Suite
struct LocalizationTests {
    @Test
    func russianPreferredLanguageUsesRussianStrings() {
        let localization = QuickCalLocalization(
            preferredLanguages: ["ru-RU", "en-US"],
            systemLocale: Locale(identifier: "ru_RU")
        )

        #expect(localization.languageIdentifier == "ru")
        #expect(localization.string(.returnToToday) == "Вернуться к сегодняшнему дню")
        #expect(localization.string(.previousMonth) == "Предыдущий месяц")
        #expect(localization.string(.nextMonth) == "Следующий месяц")
        #expect(localization.string(.showWeekNumbers) == "Показывать номера недель")
        #expect(localization.string(.weekNumbersShort) == "Недели")
        #expect(localization.string(.launchAtLogin) == "Запускать при входе")
        #expect(localization.string(.launchAtLoginShort) == "Автозапуск")
        #expect(localization.string(.menuBarInformation) == "Показывать информацию в строке меню")
        #expect(localization.string(.nextTheme) == "Следующая тема")
        #expect(localization.string(.chooseTheme) == "Выбрать тему")
        #expect(localization.string(.optionsMenu) == "Дополнительные настройки")
        #expect(localization.string(.themeLedger) == "Сроковая ведомость")
        #expect(localization.string(.themeSignalGrid) == "Signal Grid")
        #expect(localization.string(.quitQuickCal) == "Выйти из QuickCal")
        #expect(localization.string(.today) == "Сегодня")
        #expect(localization.string(.selected) == "Выбрано")
        #expect(localization.string(.dayOff) == "Выходной")
        #expect(localization.string(.sprintColumn) == "Спринты")
        #expect(localization.format(.sprintNumberFormat, 8) == "Спринт 8")
        #expect(localization.string(.currentSprint) == "Текущий спринт")
        #expect(localization.string(.noSprint) == "Нет спринта")
        #expect(localization.string(.sprintSchedule) == "Расписание спринтов")
        #expect(localization.string(.weatherVisibility) == "Показывать погоду")
        #expect(localization.string(.weatherUnavailable) == "Прогноз временно недоступен")
        #expect(localization.string(.weatherRefresh) == "Обновить прогноз")
        #expect(localization.string(.weatherLocating) == "Определяем текущее местоположение…")
        #expect(localization.string(.weatherLocationUnavailable) == "Не удалось определить местоположение.")
        #expect(localization.string(.weatherRetryLocation) == "Повторить")
        #expect(localization.format(.weatherUpdatedFormat, "14:30 · 8 авг.") == "Upd 14:30 · 8 авг.")
        #expect(localization.string(.marketVisibility) == "Показывать котировки")
        #expect(localization.string(.marketTickers) == "Тикеры через запятую")
        #expect(localization.string(.marketLoading) == "Загрузка котировок MOEX")
        #expect(localization.format(.marketDataAsOfFormat, "8 августа 2026 г.") == "Актуально на 8 августа 2026 г.")
        #expect(localization.string(.marketUnavailable) == "MOEX недоступен")
        #expect(localization.string(.marketRetryAccessibility) == "Повторить загрузку котировок MOEX")
        #expect(localization.string(.marketDirectionUp) == "рост")
        #expect(localization.format(.marketPartialFormat, "UNKNOWN") == "Не загружены: UNKNOWN")
        #expect(localization.format(.weekNumberFormat, 31) == "Неделя 31")
    }

    @Test
    func englishPreferredLanguageUsesEnglishStringsAndKeepsRegion() {
        let localization = QuickCalLocalization(
            preferredLanguages: ["en-GB", "ru-RU"],
            systemLocale: Locale(identifier: "en_GB")
        )

        #expect(localization.languageIdentifier == "en")
        #expect(localization.locale.language.languageCode?.identifier == "en")
        #expect(localization.locale.region?.identifier == "GB")
        #expect(localization.string(.returnToToday) == "Return to today")
        #expect(localization.string(.previousMonth) == "Previous month")
        #expect(localization.string(.nextMonth) == "Next month")
        #expect(localization.string(.showWeekNumbers) == "Show week numbers")
        #expect(localization.string(.weekNumbersShort) == "Weeks")
        #expect(localization.string(.launchAtLogin) == "Launch at login")
        #expect(localization.string(.launchAtLoginShort) == "Autostart")
        #expect(localization.string(.menuBarInformation) == "Show information in menu bar")
        #expect(localization.string(.nextTheme) == "Next theme")
        #expect(localization.string(.chooseTheme) == "Choose theme")
        #expect(localization.string(.optionsMenu) == "More settings")
        #expect(localization.string(.themeLedger) == "Deadline Ledger")
        #expect(localization.string(.themeSignalGrid) == "Signal Grid")
        #expect(localization.string(.quitQuickCal) == "Quit QuickCal")
        #expect(localization.string(.today) == "Today")
        #expect(localization.string(.selected) == "Selected")
        #expect(localization.string(.dayOff) == "Day off")
        #expect(localization.string(.sprintColumn) == "Sprints")
        #expect(localization.format(.sprintNumberFormat, 8) == "Sprint 8")
        #expect(localization.string(.currentSprint) == "Current sprint")
        #expect(localization.string(.noSprint) == "No sprint")
        #expect(localization.string(.sprintSchedule) == "Sprint schedule")
        #expect(localization.string(.weatherVisibility) == "Show weather")
        #expect(localization.string(.weatherUnavailable) == "Forecast is temporarily unavailable")
        #expect(localization.string(.weatherRefresh) == "Refresh forecast")
        #expect(localization.string(.weatherLocating) == "Determining current location…")
        #expect(localization.string(.weatherLocationUnavailable) == "Could not determine the current location.")
        #expect(localization.string(.weatherRetryLocation) == "Try again")
        #expect(localization.format(.weatherUpdatedFormat, "14:30 · Aug 8") == "Upd 14:30 · Aug 8")
        #expect(localization.string(.marketVisibility) == "Show quotes")
        #expect(localization.string(.marketTickers) == "Comma-separated tickers")
        #expect(localization.string(.marketLoading) == "Loading MOEX quotes")
        #expect(localization.format(.marketDataAsOfFormat, "Saturday, August 8, 2026") == "Quotes as of Saturday, August 8, 2026")
        #expect(localization.string(.marketUnavailable) == "MOEX is unavailable")
        #expect(localization.string(.marketRetryAccessibility) == "Retry loading MOEX quotes")
        #expect(localization.string(.marketDirectionDown) == "down")
        #expect(localization.format(.marketPartialFormat, "UNKNOWN") == "Not loaded: UNKNOWN")
        #expect(localization.format(.weekNumberFormat, 31) == "Week 31")
    }

    @Test
    func firstSupportedPreferredLanguageWins() {
        let localization = QuickCalLocalization(
            preferredLanguages: ["de-DE", "ru-RU", "en-GB"],
            systemLocale: Locale(identifier: "de_DE")
        )

        #expect(localization.languageIdentifier == "ru")
        #expect(localization.locale.language.languageCode?.identifier == "ru")
        #expect(localization.locale.region?.identifier == "DE")
        #expect(localization.string(.today) == "Сегодня")
    }

    @Test
    func unsupportedLanguagesFallBackToEnglishAndKeepRegion() {
        let localization = QuickCalLocalization(
            preferredLanguages: ["de-DE", "fr-FR"],
            systemLocale: Locale(identifier: "de_DE")
        )

        #expect(localization.languageIdentifier == "en")
        #expect(localization.locale.language.languageCode?.identifier == "en")
        #expect(localization.locale.region?.identifier == "DE")
        #expect(localization.string(.today) == "Today")
    }

    @Test
    func localizedCalendarKeepsRegionalWeekRules() {
        let localization = QuickCalLocalization(
            preferredLanguages: ["en-GB"],
            systemLocale: Locale(identifier: "en_GB")
        )
        var source = Calendar(identifier: .gregorian)
        source.locale = Locale(identifier: "de_DE")
        source.firstWeekday = 2
        source.minimumDaysInFirstWeek = 4

        let localized = localization.calendar(from: source)

        #expect(localized.locale?.language.languageCode?.identifier == "en")
        #expect(localized.locale?.region?.identifier == "GB")
        #expect(localized.firstWeekday == 2)
        #expect(localized.minimumDaysInFirstWeek == 4)
        #expect(localized.shortStandaloneWeekdaySymbols.first == "Sun")
    }
}
