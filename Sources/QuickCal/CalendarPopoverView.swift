import AppKit
import SwiftUI
import QuickCalKit

@MainActor
struct CalendarPopoverView: View {
    @AppStorage("showWeekNumbers") private var showWeekNumbers = true
    @ObservedObject private var themeStore: QuickCalThemeStore
    @State private var displayedMonth = Date()
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @StateObject private var selectedDates = SelectedDatesStore()
    @StateObject private var workCalendar = WorkCalendarController()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var systemColorScheme

    private let localization = QuickCalLocalization.current
    private let onThemeChanged: (QuickCalTheme) -> Void

    init(
        themeStore: QuickCalThemeStore,
        onThemeChanged: @escaping (QuickCalTheme) -> Void
    ) {
        _themeStore = ObservedObject(wrappedValue: themeStore)
        self.onThemeChanged = onThemeChanged
    }

    private var calendar: Calendar {
        localization.calendar()
    }

    private var theme: QuickCalTheme {
        themeStore.resolvedTheme(
            systemIsDark: systemColorScheme == .dark
        )
    }

    private var themeStyle: QuickCalThemeStyle {
        QuickCalThemeStyle(theme: theme)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ZStack(alignment: .top) {
                QuickCalThemeBackground(theme: theme)

                VStack(alignment: .leading, spacing: 0) {
                    dateHeader(for: context.date)

                    calendarSurface(today: context.date)

                    utilityFooter
                }
                .padding(themeStyle.shellPadding)

                if themeStyle.showsSwissStripe {
                    Rectangle()
                        .fill(Color(red: 0.875, green: 0.4, blue: 0.376))
                        .frame(height: 4)
                }
            }
            .frame(width: showWeekNumbers ? 360 : 328)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: themeStyle.outerCornerRadius,
                    style: .continuous
                )
            )
            .environment(\.quickCalThemeStyle, themeStyle)
            .environment(\.locale, localization.locale)
            .preferredColorScheme(themeStyle.colorScheme)
            .animation(
                .easeInOut(duration: reduceMotion ? 0 : 0.16),
                value: showWeekNumbers
            )
            .animation(
                .easeInOut(duration: reduceMotion ? 0 : 0.20),
                value: themeStore.manualTheme
            )
        }
        .onAppear {
            launchAtLogin.refresh()
        }
    }

    private func dateHeader(for date: Date) -> some View {
        let text = DatePresentation.fullDate(
            date,
            calendar: calendar,
            localization: localization
        )
        let displayedText = themeStyle.usesUppercaseHeaders
            ? text.uppercased(with: localization.locale)
            : text

        return Text(verbatim: displayedText)
            .font(.system(
                size: themeStyle.usesHeaderPill ? 16 : 15,
                weight: themeStyle.usesUppercaseHeaders
                    ? .bold
                    : .semibold
            ))
            .tracking(themeStyle.usesUppercaseHeaders ? 0.35 : 0)
            .foregroundStyle(
                themeStyle.usesHeaderPill
                    ? themeStyle.primaryText.opacity(0.92)
                    : themeStyle.secondaryText
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, themeStyle.usesHeaderPill ? 15 : 3)
            .padding(.vertical, themeStyle.usesHeaderPill ? 13 : 0)
            .padding(.bottom, themeStyle.usesHeaderPill ? 0 : 12)
            .background {
                if themeStyle.usesHeaderPill {
                    RoundedRectangle(
                        cornerRadius: 19,
                        style: .continuous
                    )
                    .fill(themeStyle.headerBackground)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 19,
                            style: .continuous
                        )
                        .strokeBorder(
                            themeStyle.headerBorderColor,
                            lineWidth: 1
                        )
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !themeStyle.usesHeaderPill {
                    Rectangle()
                        .fill(themeStyle.dividerColor)
                        .frame(height: 1)
                }
            }
    }

    private func calendarSurface(today: Date) -> some View {
        VStack(spacing: 9) {
            monthNavigation

            if let month = CalendarMonth(
                containing: displayedMonth,
                calendar: calendar
            ) {
                CalendarGridView(
                    month: month,
                    showWeekNumbers: showWeekNumbers,
                    today: today,
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
        }
        .padding(themeStyle.calendarPadding)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(
                cornerRadius: themeStyle.panelCornerRadius,
                style: .continuous
            )
            .fill(themeStyle.panelColor)
            .overlay {
                RoundedRectangle(
                    cornerRadius: themeStyle.panelCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    themeStyle.panelBorderColor,
                    lineWidth: 1
                )
            }
        }
        .padding(.top, themeStyle.usesHeaderPill ? 9 : 12)
        .padding(.bottom, 8)
    }

    private var monthNavigation: some View {
        HStack(spacing: 5) {
            HoverIconButton(
                title: localization.string(.previousMonth),
                systemImage: "chevron.left",
                controlSize: 32
            ) {
                moveMonth(by: -1)
            }

            Text(verbatim: monthTitle)
                .font(.system(
                    size: themeStyle.usesUppercaseHeaders ? 21 : 22,
                    weight: themeStyle.usesUppercaseHeaders
                        ? .bold
                        : .semibold
                ))
                .tracking(themeStyle.usesUppercaseHeaders ? -0.35 : -0.25)
                .foregroundStyle(themeStyle.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.80)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)

            HoverTextButton(
                title: localization.string(.today),
                help: localization.string(.returnToToday),
                action: showToday
            )

            HoverIconButton(
                title: localization.string(.nextMonth),
                systemImage: "chevron.right",
                controlSize: 32
            ) {
                moveMonth(by: 1)
            }
        }
        .frame(height: 32)
    }

    private var monthTitle: String {
        let title = DatePresentation.monthTitle(
            displayedMonth,
            calendar: calendar,
            localization: localization
        )
        return themeStyle.usesUppercaseHeaders
            ? title.uppercased(with: localization.locale)
            : title
    }

    private var utilityFooter: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(themeStyle.dividerColor)
                .frame(height: 1)

            HStack(spacing: 4) {
                compactToggle(
                    title: localization.string(.weekNumbersShort),
                    help: localization.string(.showWeekNumbers),
                    isOn: $showWeekNumbers
                )

                compactToggle(
                    title: localization.string(.launchAtLoginShort),
                    help: localization.string(.launchAtLogin),
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )

                HoverIconButton(
                    title: localization.string(.nextTheme),
                    systemImage: "paintpalette",
                    symbolSize: 15,
                    controlSize: 30,
                    action: selectNextTheme
                )

                HoverIconButton(
                    title: localization.string(.quitQuickCal),
                    systemImage: "power",
                    symbolSize: 14,
                    controlSize: 30
                ) {
                    NSApplication.shared.terminate(nil)
                }
            }

            if let message = launchAtLogin.message {
                Text(verbatim: message)
                    .font(.caption2)
                    .foregroundStyle(themeStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 5)
            }
        }
        .padding(.top, 6)
    }

    private func compactToggle(
        title: String,
        help: String,
        isOn: Binding<Bool>
    ) -> some View {
        HoverSurface(
            horizontalPadding: 4,
            verticalPadding: 4
        ) {
            Toggle(isOn: isOn) {
                Text(verbatim: title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .toggleStyle(CompactCheckboxToggleStyle())
            .foregroundStyle(themeStyle.secondaryText)
        }
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
    }

    private func selectNextTheme() {
        let nextTheme = themeStore.selectNext(
            systemIsDark: systemColorScheme == .dark
        )
        onThemeChanged(nextTheme)
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
