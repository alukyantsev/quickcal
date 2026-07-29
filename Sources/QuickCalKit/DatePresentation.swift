import Foundation

public enum DatePresentation {
    public static func fullDate(
        _ date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        localization: QuickCalLocalization = .current
    ) -> String {
        let dateWithoutYear = date.formatted(
            Date.FormatStyle(
                locale: localization.locale,
                calendar: calendar,
                timeZone: calendar.timeZone
            )
            .weekday(.wide)
            .day()
            .month(.wide)
        )

        return localization.format(
            .dateHeaderFormat,
            dateWithoutYear,
            yearString(for: date, calendar: calendar, locale: localization.locale)
        )
    }

    public static func monthTitle(
        _ date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        localization: QuickCalLocalization = .current
    ) -> String {
        let month = date.formatted(
            Date.FormatStyle(
                locale: localization.locale,
                calendar: calendar,
                timeZone: calendar.timeZone
            )
            .month(.wide)
        )

        return localization.format(
            .monthTitleFormat,
            month,
            yearString(for: date, calendar: calendar, locale: localization.locale)
        )
    }

    private static func yearString(
        for date: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        calendar.component(.year, from: date)
            .formatted(.number.grouping(.never).locale(locale))
    }
}
