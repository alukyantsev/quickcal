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

enum QuickCalHeaderPanel {
    case themes
    case options
}

@MainActor
private struct WeatherOptionsView: View {
    @ObservedObject var controller: WeatherController

    @Environment(\.quickCalThemeStyle) private var themeStyle
    @State private var locationQuery = ""
    @State private var locationResults: [WeatherLocation] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var suppressNextSearch = false

    private let localization = QuickCalLocalization.current

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(
                localization.string(.weatherVisibility),
                isOn: Binding(
                    get: { controller.settings.isVisible },
                    set: { controller.setVisibility($0) }
                )
            )
            .toggleStyle(CompactCheckboxToggleStyle())
            .font(.system(size: 13))
            .foregroundStyle(themeStyle.primaryText)
            .padding(.horizontal, 7)
            .frame(height: 29)

            if controller.settings.isVisible {
                locationControls
                automaticLocationToggle
                intervalControls
            }
        }
        .onAppear(perform: restoreManualLocationName)
        .onDisappear { searchTask?.cancel() }
    }

    @ViewBuilder
    private var locationControls: some View {
        Text(verbatim: localization.string(.weatherLocation))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(themeStyle.primaryText)
            .padding(.horizontal, 7)

        if controller.settings.locationMode == .automatic {
            automaticLocationControls
        } else {
            TextField(
                localization.string(.weatherSearchLocation),
                text: $locationQuery
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12))
            .padding(.horizontal, 7)
            .onChange(of: locationQuery) { _, query in
                scheduleLocationSearch(for: query)
            }

            ForEach(locationResults.prefix(4), id: \.self) { location in
                HoverSurface(horizontalPadding: 0, verticalPadding: 0) {
                    Button {
                        controller.setManualLocation(location)
                        searchTask?.cancel()
                        suppressNextSearch = true
                        locationQuery = location.displayName
                        locationResults = []
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: location.displayName)
                            if let detail = locationDetail(location) {
                                Text(verbatim: detail)
                                    .font(.system(size: 10))
                                    .foregroundStyle(themeStyle.secondaryText)
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(themeStyle.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: locationDetail(location).map {
                        "\(location.displayName), \($0)"
                    } ?? location.displayName))
                }
            }
        }
    }

    @ViewBuilder
    private var automaticLocationControls: some View {
        if let location = controller.settings.automaticLocation {
            currentLocationRow(location)
        } else {
            HStack(spacing: 6) {
                if controller.automaticLocationStatus == .locating
                    || controller.automaticLocationStatus == .awaitingAuthorization
                {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "location.slash")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(verbatim: automaticLocationMessage)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if controller.automaticLocationStatus == .unavailable {
                    Button {
                        controller.retryAutomaticLocation()
                    } label: {
                        Text(verbatim: localization.string(.weatherRetryLocation))
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(themeStyle.primaryText)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(themeStyle.primaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    private var automaticLocationMessage: String {
        switch controller.automaticLocationStatus {
        case .unavailable:
            localization.string(.weatherLocationUnavailable)
        case .inactive, .awaitingAuthorization, .locating:
            localization.string(.weatherLocating)
        }
    }

    private func currentLocationRow(_ location: WeatherLocation) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.system(size: 11, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: location.displayName)
                if let detail = locationDetail(location) {
                    Text(verbatim: detail)
                        .font(.system(size: 10))
                        .foregroundStyle(themeStyle.secondaryText)
                }
            }
            .font(.system(size: 12, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(themeStyle.primaryText)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var automaticLocationToggle: some View {
        Toggle(
            localization.string(.weatherAutomaticLocation),
            isOn: Binding(
                get: { controller.settings.locationMode == .automatic },
                set: { controller.setAutomaticModeEnabled($0) }
            )
        )
        .toggleStyle(CompactCheckboxToggleStyle())
        .font(.system(size: 12))
        .foregroundStyle(themeStyle.primaryText)
        .padding(.horizontal, 7)
        .padding(.top, 2)
    }

    private var intervalControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: localization.string(.weatherInterval))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(themeStyle.primaryText)

            HStack(spacing: 4) {
                ForEach(WeatherInterval.allCases, id: \.self) { interval in
                    WeatherIntervalButton(
                        interval: interval,
                        isSelected: controller.settings.interval == interval,
                        action: { controller.setInterval(interval) }
                    )
                }
            }
        }
        .padding(.horizontal, 7)
    }

    private func scheduleLocationSearch(for query: String) {
        if suppressNextSearch {
            suppressNextSearch = false
            return
        }
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            locationResults = await controller.searchLocations(query: query)
        }
    }

    private func restoreManualLocationName() {
        guard locationQuery.isEmpty,
              let location = controller.settings.manualLocation
        else { return }
        suppressNextSearch = true
        locationQuery = location.displayName
    }

    private func locationDetail(_ location: WeatherLocation) -> String? {
        let detail = [location.administrativeArea, location.country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return detail.isEmpty ? nil : detail
    }
}

private struct WeatherIntervalButton: View {
    let interval: WeatherInterval
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.quickCalThemeStyle) private var themeStyle
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("\(interval.rawValue)h")
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 24)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? themeStyle.todayColor : (isHovered ? themeStyle.hoverColor : .clear))
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? themeStyle.todayText : themeStyle.primaryText)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: reduceMotion ? 0 : 0.12), value: isHovered)
        .accessibilityLabel(Text(verbatim: "\(interval.rawValue)"))
        .accessibilityValue(Text(verbatim: isSelected ? QuickCalLocalization.current.string(.selected) : ""))
    }
}

@MainActor
private struct MarketQuoteOptionsView: View {
    @ObservedObject var controller: QuoteController

    @Environment(\.quickCalThemeStyle) private var themeStyle
    @State private var tickerInput = ""
    @FocusState private var isTickerFieldFocused: Bool

    private let localization = QuickCalLocalization.current

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(
                localization.string(.marketVisibility),
                isOn: Binding(
                    get: { controller.settings.isVisible },
                    set: { controller.setVisibility($0) }
                )
            )
            .toggleStyle(CompactCheckboxToggleStyle())
            .font(.system(size: 13))
            .foregroundStyle(themeStyle.primaryText)
            .padding(.horizontal, 7)
            .frame(height: 29)

            if controller.settings.isVisible {
                Text(verbatim: localization.string(.marketTickers))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(themeStyle.primaryText)
                    .padding(.horizontal, 7)

                TextField(localization.string(.marketTickersPlaceholder), text: $tickerInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .padding(.horizontal, 7)
                    .focused($isTickerFieldFocused)
                    .onSubmit(commitTickers)
                    .onChange(of: isTickerFieldFocused) { _, focused in
                        if !focused { commitTickers() }
                    }
                    .accessibilityLabel(Text(verbatim: localization.string(.marketTickersAccessibilityLabel)))
                    .accessibilityHint(Text(verbatim: localization.string(.marketTickersAccessibilityHint)))

                if !controller.failedTickers.isEmpty {
                    Text(verbatim: localization.format(
                        .marketFailedTickersFormat,
                        controller.failedTickers.joined(separator: ", ")
                    ))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(themeStyle.secondaryText)
                        .padding(.horizontal, 7)
                        .accessibilityLabel(Text(verbatim: localization.format(
                            .marketFailedTickersAccessibilityFormat,
                            controller.failedTickers.joined(separator: ", ")
                        )))
                }
            }
        }
        .onAppear {
            tickerInput = controller.settings.tickers.joined(separator: ", ")
        }
    }

    private func commitTickers() {
        let normalized = MarketQuoteSettings.normalizedTickers(from: tickerInput)
        tickerInput = normalized.joined(separator: ", ")
        guard normalized != controller.settings.tickers else { return }
        controller.setTickers(normalized)
    }
}

@MainActor
private struct PopupMenuRow: View {
    let title: String
    let systemImage: String
    let textColor: Color
    let action: () -> Void

    var body: some View {
        HoverSurface(horizontalPadding: 0, verticalPadding: 0) {
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
                .foregroundStyle(textColor)
                .padding(.horizontal, 7)
                .frame(height: 29)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

@MainActor
private struct MenuBarInformationOptionsView: View {
    @ObservedObject var settings: MenuBarInformationSettingsStore

    let textColor: Color
    private let localization = QuickCalLocalization.current

    var body: some View {
        PopupMenuRow(
            title: localization.string(.menuBarInformation),
            systemImage: settings.isEnabled
                ? "checkmark.square.fill"
                : "square",
            textColor: textColor
        ) {
            settings.setEnabled(!settings.isEnabled)
        }
    }
}

@MainActor
private struct SprintScheduleOptionsView: View {
    @ObservedObject var store: SprintScheduleSettingsStore
    @Binding var editingSprint: SprintSchedule.Sprint?

    @Environment(\.quickCalThemeStyle) private var themeStyle
    @State private var startDate = Date()
    @State private var firstSprintNumber = 1
    @State private var customLength = 14
    @State private var pauseStartDate = Date()
    @State private var pauseEndDate = Date()
    @State private var pendingLength: Int?
    @State private var pendingPause: SprintPause?

    private let localization = QuickCalLocalization.current

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if store.settings.startDate != nil {
                Toggle(
                    localization.string(.showSprints),
                    isOn: Binding(
                        get: { store.settings.isVisible },
                        set: { store.setVisibility($0) }
                    )
                )
                .toggleStyle(CompactCheckboxToggleStyle())
                .font(.system(size: 12))
                .foregroundStyle(themeStyle.primaryText)
                .padding(.horizontal, 7)
            }

            if store.settings.startDate == nil || store.settings.isVisible {
                scheduleConfiguration

                if let editingSprint {
                    sprintEditor(for: editingSprint)
                }

                pauseEditor
            }
        }
        .onAppear {
            guard let savedStartDate = store.settings.startDate else { return }
            startDate = savedStartDate.date() ?? startDate
            firstSprintNumber = store.settings.firstSprintNumber
            syncEditingLength()
        }
        .onChange(of: editingSprint) { _, _ in
            syncEditingLength()
        }
        .confirmationDialog(
            localization.string(.sprintHistoryWarning),
            isPresented: Binding(
                get: { pendingLength != nil || pendingPause != nil },
                set: { if !$0 { pendingLength = nil; pendingPause = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(localization.string(.sprintHistoryConfirm)) {
                if let pendingLength, let editingSprint {
                    _ = store.setLength(ofSprint: editingSprint.number, to: pendingLength)
                } else if let pendingPause {
                    _ = store.addPause(from: pendingPause.startDate, through: pendingPause.endDate)
                }
                self.pendingLength = nil
                self.pendingPause = nil
            }
            Button(localization.string(.sprintHistoryCancel), role: .cancel) {
                pendingLength = nil
                self.pendingPause = nil
            }
        } message: {
            Text(verbatim: localization.string(.sprintHistoryWarningMessage))
        }
    }

    private var scheduleConfiguration: some View {
        Group {
            DatePicker(
                localization.string(.sprintStartDate),
                selection: $startDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .font(.system(size: 12))
            .padding(.horizontal, 7)

            HStack(spacing: 6) {
                Text(verbatim: localization.string(.sprintFirstNumber))
                    .font(.system(size: 12))
                TextField("", value: $firstSprintNumber, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 48)
            }
            .foregroundStyle(themeStyle.primaryText)
            .padding(.horizontal, 7)

            HoverTextButton(
                title: localization.string(.saveSprintSchedule),
                help: localization.string(.saveSprintSchedule),
                height: 25,
                horizontalPadding: 7
            ) {
                guard
                    firstSprintNumber > 0,
                    let calendarDate = CalendarDate(date: startDate)
                else { return }
                store.configure(
                    startDate: calendarDate,
                    firstSprintNumber: firstSprintNumber
                )
            }
            .padding(.horizontal, 7)
        }
    }

    @ViewBuilder
    private func sprintEditor(for sprint: SprintSchedule.Sprint) -> some View {
        Rectangle().fill(themeStyle.dividerColor.opacity(0.5)).frame(height: 1).padding(.vertical, 2)
        Text(verbatim: localization.format(.editSprintLengthFormat, sprint.number))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(themeStyle.primaryText)
            .padding(.horizontal, 7)
        HStack(spacing: 4) {
            ForEach([7, 14, 21], id: \.self) { length in
                HoverTextButton(
                    title: "\(length)",
                    help: localization.string(.sprintLengthDays),
                    height: 25,
                    horizontalPadding: 7
                ) {
                    requestLength(length, for: sprint)
                }
            }
            TextField(localization.string(.sprintLengthDays), value: $customLength, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 48)
            HoverTextButton(
                title: localization.string(.applySprintLength),
                help: localization.string(.applySprintLength),
                height: 25,
                horizontalPadding: 7
            ) {
                requestLength(customLength, for: sprint)
            }
        }
        .padding(.horizontal, 7)
    }

    private var pauseEditor: some View {
        VStack(alignment: .leading, spacing: 5) {
            Rectangle().fill(themeStyle.dividerColor.opacity(0.5)).frame(height: 1).padding(.vertical, 2)
            Text(verbatim: localization.string(.sprintPause))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(themeStyle.primaryText)
                .padding(.horizontal, 7)
            DatePicker(localization.string(.sprintPauseStart), selection: $pauseStartDate, displayedComponents: .date)
                .datePickerStyle(.compact).font(.system(size: 12)).padding(.horizontal, 7)
            DatePicker(localization.string(.sprintPauseEnd), selection: $pauseEndDate, displayedComponents: .date)
                .datePickerStyle(.compact).font(.system(size: 12)).padding(.horizontal, 7)
            HoverTextButton(
                title: localization.string(.addSprintPause),
                help: localization.string(.addSprintPause),
                height: 25,
                horizontalPadding: 7
            ) {
                guard let start = CalendarDate(date: pauseStartDate), let end = CalendarDate(date: pauseEndDate), start <= end else { return }
                if requiresHistoryConfirmation(from: start) {
                    pendingPause = .init(startDate: start, endDate: end)
                }
                else { _ = store.addPause(from: start, through: end) }
            }
            .padding(.horizontal, 7)

            ForEach(store.settings.pauses, id: \.startDate) { pause in
                HStack(spacing: 6) {
                    Text(verbatim: "\(pause.startDate.year)-\(pause.startDate.month)-\(pause.startDate.day) — \(pause.endDate.year)-\(pause.endDate.month)-\(pause.endDate.day)")
                        .font(.system(size: 11))
                        .foregroundStyle(themeStyle.secondaryText)
                    Spacer(minLength: 0)
                    HoverIconButton(
                        title: localization.string(.removeSprintPause),
                        systemImage: "minus.circle",
                        symbolSize: 11,
                        controlSize: 24
                    ) {
                        _ = store.removePause(pause)
                    }
                }
                .padding(.horizontal, 7)
            }
        }
    }

    private func requestLength(_ length: Int, for sprint: SprintSchedule.Sprint) {
        guard length > 0 else { return }
        if requiresHistoryConfirmation(from: sprint.startDate) { pendingLength = length }
        else { _ = store.setLength(ofSprint: sprint.number, to: length) }
    }

    private func requiresHistoryConfirmation(from date: CalendarDate) -> Bool {
        date <= CalendarDate(date: .now)!
    }

    private func syncEditingLength() {
        if let editingSprint {
            customLength = editingSprint.lengthInDays
        }
    }
}

@MainActor
struct CalendarPopoverView: View {
    @AppStorage("showWeekNumbers") private var showWeekNumbers = true
    @ObservedObject private var themeStore: QuickCalThemeStore
    @State private var displayedMonth = Date()
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @StateObject private var selectedDates = SelectedDatesStore()
    @StateObject private var workCalendar = WorkCalendarController()
    @StateObject private var sprintSettings = SprintScheduleSettingsStore()
    @State private var editingSprint: SprintSchedule.Sprint?
    @State private var activePanel: QuickCalHeaderPanel?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var systemColorScheme

    private let localization = QuickCalLocalization.current
    private let onThemeChanged: (QuickCalTheme) -> Void
    private let weatherController: WeatherController?
    private let quoteController: QuoteController?
    private let menuBarInformationSettings: MenuBarInformationSettingsStore?
    private let refreshCoordinator: ForegroundRefreshCoordinator?
    private let onRefresh: (() -> Void)?
    private let usesWeatherWheelPager: Bool

    init(
        themeStore: QuickCalThemeStore,
        weatherController: WeatherController? = nil,
        quoteController: QuoteController? = nil,
        menuBarInformationSettings: MenuBarInformationSettingsStore? = nil,
        refreshCoordinator: ForegroundRefreshCoordinator? = nil,
        onRefresh: (() -> Void)? = nil,
        initialActivePanel: QuickCalHeaderPanel? = nil,
        usesWeatherWheelPager: Bool = true,
        onThemeChanged: @escaping (QuickCalTheme) -> Void
    ) {
        _themeStore = ObservedObject(wrappedValue: themeStore)
        _activePanel = State(initialValue: initialActivePanel)
        self.weatherController = weatherController
        self.quoteController = quoteController
        self.menuBarInformationSettings = menuBarInformationSettings
        self.refreshCoordinator = refreshCoordinator
        self.onRefresh = onRefresh
        self.usesWeatherWheelPager = usesWeatherWheelPager
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
            .frame(width: calendarWidth)
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
                .easeInOut(duration: reduceMotion ? 0 : 0.16),
                value: sprintSettings.settings.isVisible
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
            calendarHeader

            if let month = CalendarMonth(
                containing: displayedMonth,
                calendar: calendar
            ) {
                CalendarGridView(
                    month: month,
                    showWeekNumbers: showWeekNumbers,
                    sprintSchedule: sprintSchedule(for: month),
                    today: today,
                    selectedDates: selectedDates.selectedDates,
                    workdayStatus: { workCalendar.status(for: $0) },
                    localization: localization,
                    onToggleDate: { selectedDates.toggle($0) },
                    onEditSprint: { sprint in
                        editingSprint = sprint
                        activePanel = .options
                    }
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

                if let weatherController {
                    WeatherRailView(
                        controller: weatherController,
                        onRefresh: onRefresh,
                        usesWheelPager: usesWeatherWheelPager
                    )
                }

                if let quoteController {
                    QuoteRailView(controller: quoteController, onRefresh: onRefresh)
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
        .overlay {
            if activePanel != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activePanel = nil
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            popupPanel
                .padding(.top, 36)
                .zIndex(10)
        }
        .onExitCommand {
            activePanel = nil
        }
    }

    private var calendarWidth: CGFloat {
        let baseWidth: CGFloat = showWeekNumbers ? 376 : 344
        return baseWidth + (sprintSettings.settings.isVisible ? 44 : 0)
    }

    private func sprintSchedule(for month: CalendarMonth) -> SprintSchedule? {
        guard
            sprintSettings.settings.isVisible,
            let startDate = sprintSettings.settings.startDate
        else { return nil }
        return SprintSchedule(
            startDate: startDate,
            firstSprintNumber: sprintSettings.settings.firstSprintNumber,
            defaultLengthInDays: sprintSettings.settings.defaultLengthInDays,
            lengthOverrides: sprintSettings.settings.lengthOverrides,
            pauses: sprintSettings.settings.pauses,
            timeZone: month.calendar.timeZone
        )
    }

    private var calendarHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            monthNavigation
            if let weatherController, let quoteController, let refreshCoordinator {
                NetworkHeaderContextView(
                    weatherController: weatherController,
                    quoteController: quoteController,
                    refreshCoordinator: refreshCoordinator
                ) {
                    headerUtilities
                }
            } else if let weatherController {
                WeatherHeaderContextView(controller: weatherController) {
                    headerUtilities
                }
            }
        }
        .padding(.bottom, themeStyle.usesWeekRules ? 0 : 4)
        .overlay(alignment: .bottom) {
            if !themeStyle.usesWeekRules {
                Rectangle()
                    .fill(themeStyle.dividerColor)
                    .frame(height: 1)
            }
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
            headerUtilityPlacement
        }
        .frame(height: 32)
        .padding(.bottom, 2)
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

            headerUtilityPlacement
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
            headerUtilityPlacement
        }
        .frame(height: 34)
        .padding(.bottom, 2)
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

    private var headerUtilities: some View {
        HStack(spacing: 4) {
            themeMenu
            optionsMenu
        }
    }

    @ViewBuilder
    private var headerUtilityPlacement: some View {
        if let weatherController, let quoteController {
            NetworkHeaderUtilityPlacement(
                weatherController: weatherController,
                quoteController: quoteController
            ) {
                headerUtilities
            }
        } else if let weatherController {
            WeatherHeaderUtilityPlacement(controller: weatherController) {
                headerUtilities
            }
        } else {
            headerUtilities
        }
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
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 3) {
                popupRow(
                    title: localization.string(.showWeekNumbers),
                    systemImage: showWeekNumbers
                        ? "checkmark.square.fill"
                        : "square"
                ) {
                    showWeekNumbers.toggle()
                }

                if let menuBarInformationSettings {
                    MenuBarInformationOptionsView(
                        settings: menuBarInformationSettings,
                        textColor: popupTextColor
                    )
                }

                popupRow(
                    title: localization.string(.launchAtLogin),
                    systemImage: launchAtLogin.isEnabled
                        ? "checkmark.square.fill"
                        : "square"
                ) {
                    launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
                }

                if let weatherController {
                    Rectangle()
                        .fill(popupDividerColor)
                        .frame(height: 1)
                        .padding(.vertical, 2)

                    WeatherOptionsView(controller: weatherController)
                }

                if let quoteController {
                    Rectangle()
                        .fill(popupDividerColor)
                        .frame(height: 1)
                        .padding(.vertical, 2)

                    MarketQuoteOptionsView(controller: quoteController)
                }

                Rectangle()
                    .fill(popupDividerColor)
                    .frame(height: 1)
                    .padding(.vertical, 2)

                SprintScheduleOptionsView(
                    store: sprintSettings,
                    editingSprint: $editingSprint
                )

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
        }
        .scrollIndicators(.automatic)
        .frame(maxHeight: 440)
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
        PopupMenuRow(
            title: title,
            systemImage: systemImage,
            textColor: popupTextColor,
            action: action
        )
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
        switch theme {
        case .systemLight: Color(rgb: 0xF7F8FA)
        case .systemDark: Color(rgb: 0x303944)
        case .swissLight: Color(rgb: 0xFBFAF6)
        case .swissDark: Color(rgb: 0x2A1E24)
        case .colorLight: Color(rgb: 0xFFFBFE)
        case .colorDark: Color(rgb: 0x3D2446)
        case .ledgerLight: Color(rgb: 0xF2EFE6)
        case .ledgerDark: Color(rgb: 0x2B2119)
        case .prismLight: Color(rgb: 0xF1FAFA)
        case .prismDark: Color(rgb: 0x143C4C)
        case .signalGridLight: Color(rgb: 0xF3F5F1)
        case .signalGridDark: Color(rgb: 0x17382F)
        case .titaniumChronoLight: Color(rgb: 0xF8F8F3)
        case .titaniumChronoDark: Color(rgb: 0x2B3A43)
        case .monochromeLight: Color(rgb: 0xFAFAF8)
        case .monochromeDark: Color(rgb: 0x292632)
        }
    }

    private var popupTextColor: Color {
        themeStyle.primaryText
    }

    private var popupDividerColor: Color {
        themeStyle.dividerColor
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

@MainActor
private struct WeatherHeaderContextView<Controls: View>: View {
    @ObservedObject var controller: WeatherController
    let controls: () -> Controls

    @Environment(\.quickCalThemeStyle) private var themeStyle

    private let localization = QuickCalLocalization.current

    var body: some View {
        if let context = controller.headerContext {
            HStack(spacing: 5) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(verbatim: context.location.displayName)
                    .lineLimit(1)
                    .layoutPriority(1)
                Rectangle()
                    .fill(themeStyle.dividerColor)
                    .frame(width: 1, height: 11)
                Text(verbatim: localization.format(
                    .weatherUpdatedFormat,
                    Self.updatedString(context.fetchedAt)
                ))
                .lineLimit(1)
                Spacer(minLength: 0)
                controls()
            }
            .font(.system(
                size: 10,
                weight: .medium,
                design: themeStyle.layout == .instrumentGrid ? .monospaced : themeStyle.dayFontDesign
            ))
            .foregroundStyle(themeStyle.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .accessibilityElement(children: .combine)
        }
    }

    private static func updatedString(_ date: Date) -> String {
        let time = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("dMMM")
        return "\(time) · \(dateFormatter.string(from: date))"
    }
}

@MainActor
private struct WeatherHeaderUtilityPlacement<Controls: View>: View {
    @ObservedObject var controller: WeatherController
    let controls: () -> Controls

    var body: some View {
        if controller.headerContext == nil {
            controls()
        }
    }
}

@MainActor
private struct NetworkHeaderContextView<Controls: View>: View {
    @ObservedObject var weatherController: WeatherController
    @ObservedObject var quoteController: QuoteController
    @ObservedObject var refreshCoordinator: ForegroundRefreshCoordinator
    let controls: () -> Controls

    @Environment(\.quickCalThemeStyle) private var themeStyle

    private let localization = QuickCalLocalization.current

    var body: some View {
        if weatherController.settings.isVisible || quoteController.settings.isVisible {
            HStack(spacing: 5) {
                if let weather = weatherController.headerContext {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(verbatim: weather.location.displayName)
                        .lineLimit(1)
                        .layoutPriority(1)
                }

                if weatherController.headerContext != nil && quoteController.settings.isVisible {
                    separator
                }

                if quoteController.settings.isVisible {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10, weight: .semibold))
                        .accessibilityLabel(Text(verbatim: "MOEX"))
                    Text(verbatim: "MOEX")
                        .lineLimit(1)
                }

                if let fetchedAt = refreshCoordinator.lastCompletedRefreshAt {
                    separator
                    Text(verbatim: localization.format(
                        .weatherUpdatedFormat,
                        Self.updatedString(fetchedAt)
                    ))
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
                controls()
            }
            .font(.system(
                size: 10,
                weight: .medium,
                design: themeStyle.layout == .instrumentGrid ? .monospaced : themeStyle.dayFontDesign
            ))
            .foregroundStyle(themeStyle.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .accessibilityElement(children: .combine)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(themeStyle.dividerColor)
            .frame(width: 1, height: 11)
    }

    private static func updatedString(_ date: Date) -> String {
        let time = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("dMMM")
        return "\(time) · \(dateFormatter.string(from: date))"
    }
}

@MainActor
private struct NetworkHeaderUtilityPlacement<Controls: View>: View {
    @ObservedObject var weatherController: WeatherController
    @ObservedObject var quoteController: QuoteController
    let controls: () -> Controls

    var body: some View {
        if !weatherController.settings.isVisible && !quoteController.settings.isVisible {
            controls()
        }
    }
}
