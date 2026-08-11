import SwiftUI
import QuickCalKit

struct CalendarGridView: View {
    let month: CalendarMonth
    let showWeekNumbers: Bool
    let sprintSchedule: SprintSchedule?
    let today: Date
    let selectedDates: Set<CalendarDate>
    let workdayStatus: (Date) -> WorkdayStatus
    let localization: QuickCalLocalization
    let onToggleDate: (CalendarDate) -> Void

    @Environment(\.quickCalThemeStyle) private var themeStyle

    private let cellWidth: CGFloat = 34
    private let rowSpacing: CGFloat = 3

    var body: some View {
        VStack(spacing: rowSpacing) {
            HStack(spacing: 4) {
                ForEach(Array(month.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(
                            size: 12,
                            weight: .semibold,
                            design: themeStyle.calendarLabelFontDesign
                        ))
                        .foregroundStyle(themeStyle.secondaryText)
                        .frame(width: cellWidth)
                }
                if showWeekNumbers {
                    Text(verbatim: localization.string(.weekNumberShort))
                        .font(.system(
                            size: 11,
                            weight: .semibold,
                            design: themeStyle.calendarLabelFontDesign
                        ))
                        .foregroundStyle(
                            themeStyle.secondaryText.opacity(
                                themeStyle.weekNumberOpacity
                            )
                        )
                        .frame(width: 28)
                }
                if sprintSchedule != nil {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            themeStyle.secondaryText.opacity(
                                themeStyle.weekNumberOpacity
                            )
                        )
                        .frame(width: 32)
                        .accessibilityLabel(
                            Text(verbatim: localization.string(.sprintColumn))
                        )
                }
            }
            .padding(.bottom, themeStyle.usesWeekRules ? 3 : 0)
            .overlay(alignment: .bottom) {
                if themeStyle.usesWeekRules {
                    Rectangle()
                        .fill(
                            themeStyle.dividerColor.opacity(
                                themeStyle.headerRuleOpacity
                            )
                        )
                        .frame(height: 1)
                }
            }

            ForEach(month.weeks) { week in
                let calendarDates = week.days.compactMap {
                    CalendarDate(
                        date: $0.date,
                        timeZone: month.calendar.timeZone
                    )
                }
                let sprintNumbers = sprintSchedule?.sprintNumbers(
                    for: week.days.map(\.date)
                ) ?? []
                let currentSprint = sprintSchedule?.sprint(for: today)

                HStack(spacing: 4) {
                    ForEach(
                        Array(week.days.enumerated()),
                        id: \.element.id
                    ) { index, day in
                        let calendarDate = CalendarDate(
                            date: day.date,
                            timeZone: month.calendar.timeZone
                        )
                        let segment = calendarDates.count == week.days.count
                            ? SelectionSegment.forDay(
                                at: index,
                                in: calendarDates,
                                selectedDates: selectedDates
                            )
                            : .none

                        CalendarDayCell(
                            day: day,
                            calendarDate: calendarDate,
                            selectionSegment: segment,
                            isToday: month.isToday(
                                day,
                                relativeTo: today
                            ),
                            isInCurrentSprint: currentSprint.map {
                                $0.number == sprintSchedule?.sprint(for: day.date)?.number
                            } ?? false,
                            sprintNumber: sprintSchedule?.sprint(for: day.date)?.number,
                            workdayStatus: workdayStatus(day.date),
                            calendar: month.calendar,
                            localization: localization,
                            onToggle: onToggleDate
                        )
                    }
                    if showWeekNumbers {
                        Text(week.weekOfYear, format: .number)
                            .font(.system(
                                size: 11,
                                weight: .medium,
                                design: themeStyle.dayFontDesign
                            ))
                            .monospacedDigit()
                            .foregroundStyle(
                                themeStyle.secondaryText.opacity(
                                    themeStyle.weekNumberOpacity
                                )
                            )
                            .frame(width: 28)
                            .accessibilityLabel(
                                Text(verbatim: localization.format(
                                    .weekNumberFormat,
                                    week.weekOfYear
                                ))
                            )
                    }
                    if sprintSchedule != nil {
                        Text(verbatim: sprintDisplayLabel(sprintNumbers))
                            .font(.system(
                                size: 11,
                                weight: .medium,
                                design: themeStyle.dayFontDesign
                            ))
                            .monospacedDigit()
                            .foregroundStyle(
                                themeStyle.secondaryText.opacity(
                                    themeStyle.weekNumberOpacity
                                )
                            )
                            .frame(width: 32)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .accessibilityLabel(
                                Text(verbatim: sprintAccessibilityLabel(
                                    sprintNumbers,
                                    localization: localization
                                ))
                            )
                    }
                }
                .overlay(alignment: .bottom) {
                    if themeStyle.usesWeekRules {
                        Rectangle()
                            .fill(
                                themeStyle.dividerColor.opacity(
                                    themeStyle.rowRuleOpacity
                                )
                            )
                            .frame(height: 1)
                            .offset(y: 2)
                    }
                }
            }
        }
        .environment(\.locale, localization.locale)
    }

    private func sprintAccessibilityLabel(
        _ sprintNumbers: [Int],
        localization: QuickCalLocalization
    ) -> String {
        if sprintNumbers.isEmpty {
            return localization.string(.noSprint)
        }
        return sprintNumbers
            .map { localization.format(.sprintNumberFormat, $0) }
            .joined(separator: ", ")
    }

    private func sprintDisplayLabel(_ sprintNumbers: [Int]) -> String {
        sprintNumbers.isEmpty
            ? "—"
            : sprintNumbers.map(String.init).joined(separator: " → ")
    }
}
