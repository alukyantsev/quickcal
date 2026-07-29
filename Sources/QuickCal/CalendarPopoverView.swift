import AppKit
import SwiftUI
import QuickCalKit

struct CalendarPopoverView: View {
    @AppStorage("showWeekNumbers") private var showWeekNumbers = true
    @State private var displayedMonth = Date()
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @StateObject private var selectedDates = SelectedDatesStore()
    @StateObject private var workCalendar = WorkCalendarController()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let localization = QuickCalLocalization.current

    private var calendar: Calendar {
        localization.calendar()
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: DatePresentation.fullDate(
                    context.date,
                    calendar: calendar,
                    localization: localization
                ))
                .font(.headline)
                .foregroundStyle(.secondary)

                Divider()

                monthNavigation

                if let month = CalendarMonth(
                    containing: displayedMonth,
                    calendar: calendar
                ) {
                    CalendarGridView(
                        month: month,
                        showWeekNumbers: showWeekNumbers,
                        today: context.date,
                        selectedDates: selectedDates.selectedDates,
                        workdayStatus: { workCalendar.status(for: $0) },
                        localization: localization,
                        onToggleDate: { selectedDates.toggle($0) }
                    )
                    .task(id: month.start) {
                        await workCalendar.load(month: month)
                    }
                } else {
                    HoverActionButton(
                        title: localization.string(.returnToToday),
                        action: showToday
                    )
                }

                Divider()

                HoverSurface {
                    Toggle(isOn: $showWeekNumbers) {
                        Text(verbatim: localization.string(.showWeekNumbers))
                    }
                    .toggleStyle(.checkbox)
                }

                HoverSurface {
                    Toggle(
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        )
                    ) {
                        Text(verbatim: localization.string(.launchAtLogin))
                    }
                    .toggleStyle(.checkbox)
                }

                if let message = launchAtLogin.message {
                    Text(verbatim: message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                }

                Divider()

                HoverActionButton(
                    title: localization.string(.quitQuickCal)
                ) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(16)
            .frame(width: showWeekNumbers ? 342 : 310)
            .animation(
                .easeInOut(duration: reduceMotion ? 0 : 0.16),
                value: showWeekNumbers
            )
            .environment(\.locale, localization.locale)
        }
        .onAppear {
            launchAtLogin.refresh()
        }
    }

    private var monthNavigation: some View {
        ZStack {
            Text(verbatim: DatePresentation.monthTitle(
                displayedMonth,
                calendar: calendar,
                localization: localization
            ))
            .font(.title2.weight(.semibold))

            HStack(spacing: 2) {
                HoverIconButton(
                    title: localization.string(.previousMonth),
                    systemImage: "chevron.left"
                ) {
                    moveMonth(by: -1)
                }

                Spacer()

                HoverIconButton(
                    title: localization.string(.returnToToday),
                    systemImage: "calendar.badge.clock",
                    symbolSize: 15,
                    controlSize: 30,
                    action: showToday
                )

                HoverIconButton(
                    title: localization.string(.nextMonth),
                    systemImage: "chevron.right"
                ) {
                    moveMonth(by: 1)
                }
            }
        }
        .frame(height: 32)
    }

    private func showToday() {
        let now = Date()
        if let interval = calendar.dateInterval(of: .month, for: now) {
            displayedMonth = interval.start
        } else {
            displayedMonth = now
        }
    }

    private func moveMonth(by offset: Int) {
        guard
            let next = calendar.date(
                byAdding: .month,
                value: offset,
                to: displayedMonth
            ),
            let interval = calendar.dateInterval(of: .month, for: next)
        else {
            showToday()
            return
        }
        displayedMonth = interval.start
    }
}
