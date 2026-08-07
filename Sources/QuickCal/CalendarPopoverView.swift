/*
 THESIS: QuickCal shows the structure of a month in one gesture and refuses
 duplicated date headers or a permanent settings footer.
 OWN-WORLD: Eight paired theme families share three grammars: native toolbar,
 deadline ledger, and instrument grid. State color, geometry, and typography
 change by family while calendar behavior stays identical.
 STORY: Open, read the month, mark dates, adjust rare settings, return to work.
 FIRST VIEWPORT: One compact month header, dominant seven-column grid, optional
 week numbers on the right, visible theme control, and an ellipsis settings menu.
 FORM: Operate mode; user-approved Native Toolbar v3, Deadline Ledger v3, and
 Instrument Grid v3 compositions.
 FINISH: unreviewed and undocumented is unfinished; this build ends with the
 finish review, the verdict, and DESIGN.md
*/

import AppKit
import SwiftUI
import QuickCalKit

private enum QuickCalHeaderPanel {
    case themes
    case options
}

@MainActor
struct CalendarPopoverView: View {
    @AppStorage("showWeekNumbers") private var showWeekNumbers = true
    @ObservedObject private var themeStore: QuickCalThemeStore
    @State private var displayedMonth = Date()
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @StateObject private var selectedDates = SelectedDatesStore()
    @StateObject private var workCalendar = WorkCalendarController()
    @State private var activePanel: QuickCalHeaderPanel?

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
            ZStack {
                QuickCalThemeBackground(theme: theme)

                calendarSurface(today: context.date)
                    .padding(themeStyle.shellPadding)
            }
            .frame(width: showWeekNumbers ? 376 : 344)
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

    private func calendarSurface(today: Date) -> some View {
        VStack(spacing: themeStyle.usesWeekRules ? 7 : 9) {
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

                if let vacation = VacationCountdown.currentOrUpcoming(
                    from: selectedDates.selectedDates,
                    now: today,
                    timeZone: month.calendar.timeZone
                ) {
                    Text(verbatim: VacationPresentation.string(
                        for: vacation,
                        timeZone: month.calendar.timeZone,
                        localization: localization
                    ))
                    .font(.caption)
                    .foregroundStyle(themeStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 3)
                }
            } else {
                HoverActionButton(
                    title: localization.string(.returnToToday),
                    action: showToday
                )
            }

            if let message = launchAtLogin.message {
                Text(verbatim: message)
                    .font(.caption2)
                    .foregroundStyle(themeStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 5)
            }
        }
        .padding(themeStyle.calendarPadding)
        .padding(.bottom, activePanel == .themes ? 42 : 0)
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
        .overlay(alignment: .topTrailing) {
            popupPanel
                .padding(.top, 36)
                .zIndex(10)
        }
    }

    @ViewBuilder
    private var monthNavigation: some View {
        switch themeStyle.layout {
        case .nativeToolbar:
            nativeToolbar
        case .deadlineLedger:
            deadlineLedgerToolbar
        case .instrumentGrid:
            instrumentGridToolbar
        }
    }

    private var nativeToolbar: some View {
        HStack(spacing: 4) {
            monthTitleView

            Spacer(minLength: 4)

            previousMonthButton
            todayButton
            nextMonthButton
            themeMenu
            optionsMenu
        }
        .frame(height: 32)
        .padding(.bottom, 2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(themeStyle.dividerColor)
                .frame(height: 1)
                .offset(y: 5)
        }
    }

    private var deadlineLedgerToolbar: some View {
        HStack(spacing: 5) {
            monthTitleView

            Spacer(minLength: 5)

            HStack(spacing: 0) {
                previousMonthButton
                todayButton
                nextMonthButton
            }
            .background {
                RoundedRectangle(
                    cornerRadius: themeStyle.controlCornerRadius,
                    style: .continuous
                )
                .strokeBorder(themeStyle.dividerColor, lineWidth: 1)
            }

            themeMenu
            optionsMenu
        }
        .frame(height: 34)
        .padding(.bottom, 2)
    }

    private var instrumentGridToolbar: some View {
        HStack(spacing: 5) {
            HStack(spacing: 0) {
                previousMonthButton
                nextMonthButton
            }
            .background {
                RoundedRectangle(
                    cornerRadius: themeStyle.controlCornerRadius,
                    style: .continuous
                )
                .strokeBorder(themeStyle.dividerColor, lineWidth: 1)
            }

            Spacer(minLength: 5)

            monthTitleView

            Spacer(minLength: 5)

            todayButton
            themeMenu
            optionsMenu
        }
        .frame(height: 34)
        .padding(.bottom, 2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(themeStyle.dividerColor)
                .frame(height: 1)
                .offset(y: 5)
        }
    }

    private var monthTitleView: some View {
        Text(verbatim: monthTitle)
            .font(.system(
                size: themeStyle.monthFontSize,
                weight: themeStyle.monthFontWeight,
                design: themeStyle.monthFontDesign
            ))
            .monospacedDigit()
            .tracking(themeStyle.uppercaseMonth ? 0.2 : -0.2)
            .foregroundStyle(themeStyle.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .allowsTightening(true)
    }

    private var previousMonthButton: some View {
        HoverIconButton(
            title: localization.string(.previousMonth),
            systemImage: "chevron.left",
            symbolSize: 14,
            controlSize: 28
        ) {
            moveMonth(by: -1)
        }
    }

    private var nextMonthButton: some View {
        HoverIconButton(
            title: localization.string(.nextMonth),
            systemImage: "chevron.right",
            symbolSize: 14,
            controlSize: 28
        ) {
            moveMonth(by: 1)
        }
    }

    private var todayButton: some View {
        HoverTextButton(
            title: localization.string(.today),
            help: localization.string(.returnToToday),
            height: 28,
            horizontalPadding: 7,
            action: showToday
        )
    }

    private var themeMenu: some View {
        headerPanelButton(
            title: localization.string(.chooseTheme),
            systemImage: "paintpalette",
            panel: .themes
        )
    }

    private var optionsMenu: some View {
        headerPanelButton(
            title: localization.string(.optionsMenu),
            systemImage: "ellipsis",
            panel: .options
        )
    }

    private func headerPanelButton(
        title: String,
        systemImage: String,
        panel: QuickCalHeaderPanel
    ) -> some View {
        Button {
            activePanel = activePanel == panel ? nil : panel
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))

                if panel == .themes {
                    Circle()
                        .fill(themeStyle.todayColor)
                        .frame(width: 7, height: 7)
                        .overlay {
                            Circle().strokeBorder(
                                themeStyle.primaryText,
                                lineWidth: 1
                            )
                        }
                        .offset(x: 2, y: -2)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(themeStyle.secondaryText)
        .background {
            RoundedRectangle(
                cornerRadius: themeStyle.controlCornerRadius,
                style: .continuous
            )
            .fill(activePanel == panel ? themeStyle.hoverColor : .clear)
        }
        .help(Text(verbatim: title))
        .accessibilityLabel(Text(verbatim: title))
    }

    @ViewBuilder
    private var popupPanel: some View {
        switch activePanel {
        case .themes:
            themePanel
        case .options:
            optionsPanel
        case nil:
            EmptyView()
        }
    }

    private var themePanel: some View {
        VStack(alignment: .leading, spacing: 5) {
            popupRow(
                title: localization.string(.useSystemAppearance),
                systemImage: themeStore.manualTheme == nil
                    ? "checkmark.circle.fill"
                    : "circle.lefthalf.filled"
            ) {
                themeStore.useSystemAppearance()
                activePanel = nil
                onThemeChanged(themeStore.resolvedTheme(
                    systemIsDark: systemColorScheme == .dark
                ))
            }

            Rectangle()
                .fill(popupDividerColor)
                .frame(height: 1)

            ForEach(QuickCalThemeFamily.allCases) { family in
                HStack(spacing: 7) {
                    Text(verbatim: localization.string(family.localizationKey))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(popupTextColor)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    themeChoiceButton(family: family, appearance: .light)
                    themeChoiceButton(family: family, appearance: .dark)
                }
                .frame(height: 26)
            }
        }
        .padding(9)
        .frame(width: 238)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(popupBackgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(popupDividerColor, lineWidth: 1)
                }
                .shadow(
                    color: .black.opacity(theme.isDark ? 0.42 : 0.18),
                    radius: 14,
                    x: 0,
                    y: 7
                )
        }
    }

    private var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 3) {
            popupRow(
                title: localization.string(.showWeekNumbers),
                systemImage: showWeekNumbers
                    ? "checkmark.square.fill"
                    : "square"
            ) {
                showWeekNumbers.toggle()
                activePanel = nil
            }

            popupRow(
                title: localization.string(.launchAtLogin),
                systemImage: launchAtLogin.isEnabled
                    ? "checkmark.square.fill"
                    : "square"
            ) {
                launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
                activePanel = nil
            }

            Rectangle()
                .fill(popupDividerColor)
                .frame(height: 1)
                .padding(.vertical, 2)

            popupRow(
                title: localization.string(.quitQuickCal),
                systemImage: "power"
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(7)
        .frame(width: 218)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(popupBackgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(popupDividerColor, lineWidth: 1)
                }
                .shadow(
                    color: .black.opacity(theme.isDark ? 0.42 : 0.18),
                    radius: 14,
                    x: 0,
                    y: 7
                )
        }
    }

    private func popupRow(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 17)

                Text(verbatim: title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(popupTextColor)
            .padding(.horizontal, 7)
            .frame(height: 29)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func themeChoiceButton(
        family: QuickCalThemeFamily,
        appearance: QuickCalThemeAppearance
    ) -> some View {
        let candidate = QuickCalTheme.theme(
            family: family,
            appearance: appearance
        )
        let isSelected = candidate == theme
        let appearanceName = localization.string(
            appearance == .light ? .appearanceLight : .appearanceDark
        )
        let accessibleName = "\(localization.string(family.localizationKey)), \(appearanceName)"

        return Button {
            activePanel = nil
            selectTheme(candidate)
        } label: {
            Image(systemName: appearance == .light ? "sun.max" : "moon")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    isSelected ? themeStyle.todayText : popupTextColor
                )
                .frame(width: 25, height: 22)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? themeStyle.todayColor : .clear)
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 5,
                                style: .continuous
                            )
                            .strokeBorder(popupDividerColor, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: accessibleName))
        .accessibilityLabel(Text(verbatim: accessibleName))
    }

    private var popupBackgroundColor: Color {
        theme.isDark ? Color(rgb: 0x24282D) : Color(rgb: 0xFFFFFF)
    }

    private var popupTextColor: Color {
        theme.isDark ? Color(rgb: 0xF5F6F7) : Color(rgb: 0x202124)
    }

    private var popupDividerColor: Color {
        theme.isDark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.12)
    }

    private var monthTitle: String {
        let title = DatePresentation.monthTitle(
            displayedMonth,
            calendar: calendar,
            localization: localization
        )
        return themeStyle.uppercaseMonth
            ? title.uppercased(with: localization.locale)
            : title
    }

    private func selectTheme(_ selectedTheme: QuickCalTheme) {
        onThemeChanged(themeStore.select(selectedTheme))
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
