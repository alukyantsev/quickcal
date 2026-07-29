import SwiftUI
import QuickCalKit

struct CalendarGridView: View {
    let month: CalendarMonth
    let showWeekNumbers: Bool
    let today: Date
    let selectedDates: Set<CalendarDate>
    let workdayStatus: (Date) -> WorkdayStatus
    let localization: QuickCalLocalization
    let onToggleDate: (CalendarDate) -> Void

    private let cellWidth: CGFloat = 34
    private let rowSpacing: CGFloat = 3

    var body: some View {
        VStack(spacing: rowSpacing) {
            HStack(spacing: 4) {
                ForEach(Array(month.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: cellWidth)
                }
                if showWeekNumbers {
                    Color.clear.frame(width: 28, height: 1)
                }
            }

            ForEach(month.weeks) { week in
                let calendarDates = week.days.compactMap {
                    CalendarDate(
                        date: $0.date,
                        timeZone: month.calendar.timeZone
                    )
                }

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
                            workdayStatus: workdayStatus(day.date),
                            calendar: month.calendar,
                            localization: localization,
                            onToggle: onToggleDate
                        )
                    }
                    if showWeekNumbers {
                        Text(week.weekOfYear, format: .number)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 28)
                            .accessibilityLabel(
                                Text(verbatim: localization.format(
                                    .weekNumberFormat,
                                    week.weekOfYear
                                ))
                            )
                    }
                }
            }
        }
        .environment(\.locale, localization.locale)
    }
}
