import AppKit
import SwiftUI
import QuickCalKit

struct WeatherDisplayPeriod: Equatable, Identifiable {
    let point: WeatherForecastPoint

    var id: Date { point.timestamp }

    static func make(
        from forecast: WeatherForecast,
        interval: WeatherInterval,
        now: Date = Date()
    ) -> [WeatherDisplayPeriod] {
        let points = forecast.hourly.sorted { $0.timestamp < $1.timestamp }
        guard let first = points.firstIndex(where: { $0.timestamp >= now }) else {
            return []
        }
        return stride(from: first, to: points.count, by: interval.rawValue).map {
            WeatherDisplayPeriod(point: points[$0])
        }
    }

    static func symbol(for weatherCode: Int, at date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        iconStyle(for: weatherCode, at: date, timeZone: timeZone).symbol
    }

    static func iconStyle(
        for weatherCode: Int,
        at date: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> WeatherIconStyle {
        let hour = Calendar.autoupdatingCurrent.dateComponents(in: timeZone, from: date).hour ?? 12
        let isNight = hour < 6 || hour >= 20
        switch weatherCode {
        case 0:
            return WeatherIconStyle(
                symbol: isNight ? "moon.stars.fill" : "sun.max.fill",
                primary: Color(rgb: 0xF5B942), secondary: Color(rgb: 0xFFE39A)
            )
        case 1, 2:
            return WeatherIconStyle(
                symbol: isNight ? "cloud.moon.fill" : "cloud.sun.fill",
                primary: Color(rgb: 0xF5B942), secondary: Color(rgb: 0x98A2AE)
            )
        case 3:
            return WeatherIconStyle(symbol: "cloud.fill", primary: Color(rgb: 0x98A2AE), secondary: Color(rgb: 0xC2C9D1))
        case 45, 48:
            return WeatherIconStyle(symbol: "cloud.fog.fill", primary: Color(rgb: 0x87939E), secondary: Color(rgb: 0xB5BEC7))
        case 51, 53, 55, 56, 57:
            return WeatherIconStyle(symbol: "cloud.drizzle.fill", primary: Color(rgb: 0x4E9BE6), secondary: Color(rgb: 0x84BDED))
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return WeatherIconStyle(symbol: "cloud.rain.fill", primary: Color(rgb: 0x4E9BE6), secondary: Color(rgb: 0x84BDED))
        case 71, 73, 75, 77, 85, 86:
            return WeatherIconStyle(symbol: "cloud.snow.fill", primary: Color(rgb: 0x75BEDA), secondary: Color(rgb: 0xB9E4F2))
        case 95, 96, 99:
            return WeatherIconStyle(symbol: "cloud.bolt.rain.fill", primary: Color(rgb: 0x8976D8), secondary: Color(rgb: 0x4E9BE6))
        default:
            return WeatherIconStyle(symbol: "cloud.fill", primary: Color(rgb: 0x98A2AE), secondary: Color(rgb: 0xC2C9D1))
        }
    }

    static func timeString(
        for date: Date,
        locale: Locale,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("Hm")
        return formatter.string(from: date)
    }
}

struct WeatherIconStyle {
    let symbol: String
    let primary: Color
    let secondary: Color
}

struct WeatherDayGroup: Equatable, Identifiable {
    let day: Date
    let periodCount: Int

    var id: Date { day }

    static func make(
        from periods: [WeatherDisplayPeriod],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [WeatherDayGroup] {
        periods.reduce(into: []) { groups, period in
            let day = calendar.startOfDay(for: period.point.timestamp)
            if let last = groups.last, last.day == day {
                groups[groups.count - 1] = WeatherDayGroup(
                    day: day,
                    periodCount: last.periodCount + 1
                )
            } else {
                groups.append(WeatherDayGroup(day: day, periodCount: 1))
            }
        }
    }

    static func title(for day: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter.string(from: day).uppercased(with: locale)
    }
}

@MainActor
struct WeatherRailView: View {
    @ObservedObject var controller: WeatherController

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.quickCalThemeStyle) private var themeStyle

    private let localization = QuickCalLocalization.current
    @State private var firstVisibleIndex = 0

    var body: some View {
        Group {
            if controller.settings.isVisible {
                switch controller.state {
                case .fresh(let forecast): rail(for: forecast, staleAt: nil)
                case .stale(let forecast, let fetchedAt): rail(for: forecast, staleAt: fetchedAt)
                case .unavailable: unavailable
                case .noLocation: EmptyView()
                }
            } else {
                EmptyView()
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func rail(for forecast: WeatherForecast, staleAt: Date?) -> some View {
        let periods = WeatherDisplayPeriod.make(
            from: forecast,
            interval: controller.settings.interval
        )
        if periods.isEmpty {
            unavailable
        } else {
            VStack(alignment: .leading, spacing: 5) {
                periodScroller(periods)

                if staleAt != nil {
                    refreshButton
                }
            }
            .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
        }
    }

    private func periodScroller(_ periods: [WeatherDisplayPeriod]) -> some View {
        GeometryReader { geometry in
            let lastStartIndex = max(0, periods.count - 4)
            let startIndex = min(firstVisibleIndex, lastStartIndex)
            let visiblePeriods = Array(periods.dropFirst(startIndex).prefix(4))
            let dayGroups = WeatherDayGroup.make(from: visiblePeriods)

            ZStack {
                VStack(spacing: 2) {
                    HStack(spacing: 0) {
                        ForEach(dayGroups) { group in
                            Text(verbatim: WeatherDayGroup.title(
                                for: group.day,
                                locale: localization.locale
                            ))
                            .font(dayLabelFont)
                            .foregroundStyle(microTextColor)
                            .lineLimit(1)
                            .frame(
                                width: geometry.size.width
                                    * CGFloat(group.periodCount) / 4,
                                alignment: .leading
                            )
                        }
                    }
                    .frame(height: 12)

                    HStack(spacing: 0) {
                        ForEach(Array(visiblePeriods.enumerated()), id: \.element.id) { index, period in
                            WeatherPeriodCell(
                                period: period,
                                localization: localization,
                                showsTrailingDivider: index < visiblePeriods.count - 1
                            )
                            .frame(width: geometry.size.width / 4)
                        }
                    }
                }

                HStack {
                    if startIndex > 0 {
                        railArrow("chevron.left", title: localization.string(.previousMonth)) {
                            moveViewport(to: max(0, startIndex - 4))
                        }
                    }
                    Spacer()
                    if startIndex < lastStartIndex {
                        railArrow("chevron.right", title: localization.string(.nextMonth)) {
                            moveViewport(to: min(lastStartIndex, startIndex + 4))
                        }
                    }
                }
                // The day-label row sits above the cards. Offset only the
                // overlay so arrows stay on the cards' vertical centre.
                .offset(y: 7)
            }
            .background {
                WeatherRailWheelPager { direction in
                    let nextIndex = direction == .forward
                        ? min(lastStartIndex, startIndex + 4)
                        : max(0, startIndex - 4)
                    guard nextIndex != startIndex else { return }
                    moveViewport(to: nextIndex)
                }
            }
        }
        .frame(height: 96)
        .onChange(of: controller.settings.interval) { _, _ in
            firstVisibleIndex = 0
        }
    }

    private func railArrow(
        _ image: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 20, height: 28)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(themeStyle.primaryText)
        .accessibilityLabel(Text(verbatim: title))
    }

    private var unavailable: some View {
        HStack(spacing: 7) {
            Image(systemName: "cloud.slash")
            Text(verbatim: localization.string(.weatherUnavailable))
            Spacer(minLength: 0)
            refreshButton
        }
        .font(microFont)
        .foregroundStyle(microTextColor)
        .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
    }

    private var refreshButton: some View {
        Button {
            controller.refresh()
        } label: {
            if controller.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Text(verbatim: localization.string(.weatherRefresh))
            }
        }
        .buttonStyle(.plain)
        .font(microFont.weight(.semibold))
        .foregroundStyle(themeStyle.primaryText)
        .accessibilityLabel(Text(verbatim: controller.isRefreshing
            ? localization.string(.weatherRefreshing)
            : localization.string(.weatherRefresh)))
    }

    private var microTextColor: Color {
        themeStyle.theme == .colorLight ? themeStyle.primaryText : themeStyle.secondaryText
    }

    private var microFont: Font {
        .system(
            size: 10,
            weight: .medium,
            design: themeStyle.layout == .instrumentGrid ? .monospaced : themeStyle.dayFontDesign
        )
    }

    private var dayLabelFont: Font {
        .system(
            size: 9,
            weight: .semibold,
            design: themeStyle.layout == .instrumentGrid ? .monospaced : themeStyle.dayFontDesign
        )
    }

    private func moveViewport(to index: Int) {
        if reduceMotion {
            firstVisibleIndex = index
        } else {
            withAnimation(.easeInOut(duration: 0.16)) {
                firstVisibleIndex = index
            }
        }
    }

}

private struct WeatherRailWheelPager: NSViewRepresentable {
    enum Direction {
        case forward
        case backward
    }

    let onPage: (Direction) -> Void

    func makeNSView(context: Context) -> WeatherRailWheelView {
        WeatherRailWheelView(onPage: onPage)
    }

    func updateNSView(_ view: WeatherRailWheelView, context: Context) {
        view.onPage = onPage
    }
}

private final class WeatherRailWheelView: NSView {
    var onPage: (WeatherRailWheelPager.Direction) -> Void
    private var lastPageAt = Date.distantPast

    init(onPage: @escaping (WeatherRailWheelPager.Direction) -> Void) {
        self.onPage = onPage
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX
            : event.scrollingDeltaY
        guard abs(delta) > 0.5,
              Date().timeIntervalSince(lastPageAt) > 0.22
        else {
            return
        }
        lastPageAt = Date()
        onPage(delta < 0 ? .forward : .backward)
    }
}

struct WeatherPeriodCell: View {
    let period: WeatherDisplayPeriod
    let localization: QuickCalLocalization
    let showsTrailingDivider: Bool

    @Environment(\.quickCalThemeStyle) private var themeStyle

    var body: some View {
        let point = period.point
        let iconStyle = WeatherDisplayPeriod.iconStyle(
            for: point.weatherCode,
            at: point.timestamp
        )
        VStack(spacing: 2) {
            Text(verbatim: timeString(point.timestamp))
                .font(measurementFont.weight(.semibold))
            Image(systemName: iconStyle.symbol)
                .symbolRenderingMode(.palette)
                .foregroundStyle(iconStyle.primary, iconStyle.secondary)
                .font(.system(size: 18, weight: .medium))
                .frame(height: 20)
            Text(verbatim: localization.format(.weatherTemperatureFormat, point.temperatureCelsius))
                .font(measurementFont.weight(.semibold))
            HStack(spacing: 3) {
                Image(systemName: "humidity.fill")
                Text("\(point.relativeHumidity)%")
                Image(systemName: "drop.fill")
                Text("\(point.precipitationProbability)%")
            }
            .font(.system(size: 9, weight: .medium, design: measurementDesign))
            .foregroundStyle(microTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(themeStyle.primaryText)
        .overlay(alignment: .trailing) {
            if showsTrailingDivider {
                Rectangle().fill(themeStyle.dividerColor).frame(width: 1).padding(.vertical, 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: localization.format(
            .weatherPeriodAccessibilityFormat,
            timeString(point.timestamp),
            localization.format(.weatherTemperatureFormat, point.temperatureCelsius),
            point.relativeHumidity,
            point.precipitationProbability
        )))
    }

    private var measurementDesign: Font.Design {
        themeStyle.layout == .instrumentGrid ? .monospaced : themeStyle.dayFontDesign
    }

    private var measurementFont: Font {
        .system(size: 12, weight: .medium, design: measurementDesign)
    }

    private var microTextColor: Color {
        themeStyle.theme == .colorLight ? themeStyle.primaryText : themeStyle.secondaryText
    }

    private func timeString(_ date: Date) -> String {
        WeatherDisplayPeriod.timeString(for: date, locale: localization.locale)
    }
}
