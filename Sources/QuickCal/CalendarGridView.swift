import SwiftUI
import QuickCalKit

struct CalendarGridView: View {
    let month: CalendarMonth
    let showWeekNumbers: Bool
    let today: Date

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
                HStack(spacing: 4) {
                    ForEach(week.days) { day in
                        dayCell(day)
                    }
                    if showWeekNumbers {
                        Text(verbatim: "\(week.weekOfYear)")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 28)
                            .accessibilityLabel("Неделя \(week.weekOfYear)")
                    }
                }
            }
        }
    }

    private func dayCell(_ day: CalendarDay) -> some View {
        let isToday = month.isToday(day, relativeTo: today)
        return ZStack {
            if isToday {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 31, height: 31)
            }
            Text(verbatim: "\(day.number)")
                .font(.system(size: 17))
                .fontWeight(month.calendar.isDateInWeekend(day.date) ? .semibold : .regular)
                .foregroundStyle(
                    isToday
                        ? Color.white
                        : day.isInDisplayedMonth
                            ? Color.primary
                            : Color.secondary.opacity(0.65)
                )
        }
        .frame(width: cellWidth, height: cellWidth)
        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(isToday ? "Сегодня" : "")
    }
}
