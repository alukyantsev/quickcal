import AppKit
import SwiftUI
import QuickCalKit

struct CalendarDayCell: View {
    let day: CalendarDay
    let calendarDate: CalendarDate?
    let selectionSegment: SelectionSegment
    let isToday: Bool
    let workdayStatus: WorkdayStatus
    let calendar: Calendar
    let localization: QuickCalLocalization
    let onToggle: (CalendarDate) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private let cellSize: CGFloat = 34
    private let indicatorSize: CGFloat = 31
    private let connectionExtension: CGFloat = 2

    private var isSelected: Bool {
        selectionSegment != .none
    }

    private var isNonWorking: Bool {
        workdayStatus == .nonWorking
    }

    var body: some View {
        Button {
            if let calendarDate {
                onToggle(calendarDate)
            }
        } label: {
            ZStack {
                selectionBackground

                if isHovered && !isSelected && !isToday {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: indicatorSize, height: indicatorSize)
                }

                if isToday {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: indicatorSize, height: indicatorSize)

                    if isHovered {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: indicatorSize, height: indicatorSize)
                    }
                }

                Text(day.number, format: .number)
                    .font(.system(size: 17))
                    .fontWeight(isNonWorking ? .semibold : .regular)
                    .foregroundStyle(dayTextColor)
            }
            .frame(width: cellSize, height: cellSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(
            .easeOut(duration: reduceMotion ? 0 : 0.12),
            value: isHovered
        )
        .accessibilityLabel(Text(verbatim: accessibilityLabel))
        .accessibilityValue(Text(verbatim: accessibilityValue))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if selectionSegment != .none {
            UnevenRoundedRectangle(
                topLeadingRadius: connectsLeading ? 0 : indicatorSize / 2,
                bottomLeadingRadius: connectsLeading ? 0 : indicatorSize / 2,
                bottomTrailingRadius: connectsTrailing ? 0 : indicatorSize / 2,
                topTrailingRadius: connectsTrailing ? 0 : indicatorSize / 2,
                style: .continuous
            )
            .fill(
                Color(nsColor: .systemGreen)
                    .opacity(isHovered ? 0.34 : 0.26)
            )
            .frame(
                width: cellSize
                    + (connectsLeading ? connectionExtension : 0)
                    + (connectsTrailing ? connectionExtension : 0),
                height: indicatorSize
            )
            .offset(
                x: (
                    (connectsTrailing ? connectionExtension : 0)
                    - (connectsLeading ? connectionExtension : 0)
                ) / 2
            )
        }
    }

    private var connectsLeading: Bool {
        selectionSegment == .middle || selectionSegment == .trailing
    }

    private var connectsTrailing: Bool {
        selectionSegment == .leading || selectionSegment == .middle
    }

    private var dayTextColor: Color {
        if isToday {
            return .white
        }
        if isNonWorking {
            return Color(nsColor: .systemRed)
                .opacity(day.isInDisplayedMonth ? 1 : 0.55)
        }
        return day.isInDisplayedMonth
            ? .primary
            : .secondary.opacity(0.65)
    }

    private var accessibilityLabel: String {
        DatePresentation.fullDate(
            day.date,
            calendar: calendar,
            localization: localization
        )
    }

    private var accessibilityValue: String {
        var values: [String] = []
        if isToday {
            values.append(localization.string(.today))
        }
        if isSelected {
            values.append(localization.string(.selected))
        }
        if isNonWorking {
            values.append(localization.string(.dayOff))
        }
        return values.joined(separator: ", ")
    }
}
