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

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(
                "Показывать котировки",
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
                Text(verbatim: "Тикеры через запятую")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(themeStyle.primaryText)
                    .padding(.horizontal, 7)

                TextField("USDRUBF, EURRUBF, EUR/USD, IMOEX", text: $tickerInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .padding(.horizontal, 7)
                    .focused($isTickerFieldFocused)
                    .onSubmit(commitTickers)
                    .onChange(of: isTickerFieldFocused) { _, focused in
                        if !focused { commitTickers() }
                    }
                    .accessibilityLabel(Text(verbatim: "Тикеры котировок через запятую"))
                    .accessibilityHint(Text(verbatim: "Изменения сохраняются по Enter или после ухода из поля"))

                if !controller.failedTickers.isEmpty {
                    Text(verbatim: "Неизвестны или недоступны: \(controller.failedTickers.joined(separator: ", "))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(themeStyle.secondaryText)
                        .padding(.horizontal, 7)
                        .accessibilityLabel(Text(verbatim: "Неизвестные или недоступные тикеры: \(controller.failedTickers.joined(separator: ", "))"))
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
    private let weatherController: WeatherController?
    private let quoteController: QuoteController?
    private let onRefresh: (() -> Void)?

    init(
        themeStore: QuickCalThemeStore,
        weatherController: WeatherController? = nil,
        quoteController: QuoteController? = nil,
        onRefresh: (() -> Void)? = nil,
        onThemeChanged: @escaping (QuickCalTheme) -> Void
    ) {
        _themeStore = ObservedObject(wrappedValue: themeStore)
        self.weatherController = weatherController
        self.quoteController = quoteController
        self.onRefresh = onRefresh
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
            calendarHeader

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

                if let weatherController {
                    WeatherRailView(controller: weatherController, onRefresh: onRefresh)
                }

                if let quoteController {
                    QuoteRailView(controller: quoteController, onRefresh: onRefresh)
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

    private var calendarHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            monthNavigation
            if let weatherController, let quoteController {
                NetworkHeaderContextView(
                    weatherController: weatherController,
                    quoteController: quoteController
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
        VStack(alignment: .leading, spacing: 3) {
            popupRow(
                title: localization.string(.showWeekNumbers),
                systemImage: showWeekNumbers
                    ? "checkmark.square.fill"
                    : "square"
            ) {
                showWeekNumbers.toggle()
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
                .foregroundStyle(popupTextColor)
                .padding(.horizontal, 7)
                .frame(height: 29)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
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
        DateFormatter.localizedString(
            from: date,
            dateStyle: .none,
            timeStyle: .short
        )
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

                if let fetchedAt = latestFetchedAt {
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

    private var latestFetchedAt: Date? {
        [weatherController.lastForecastFetchedAt, quoteController.lastFetchedAt]
            .compactMap { $0 }
            .max()
    }

    private var separator: some View {
        Rectangle()
            .fill(themeStyle.dividerColor)
            .frame(width: 1, height: 11)
    }

    private static func updatedString(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
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
