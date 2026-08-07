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
        let hour = Calendar.autoupdatingCurrent.dateComponents(in: timeZone, from: date).hour ?? 12
        let isNight = hour < 6 || hour >= 20
        switch weatherCode {
        case 0: return isNight ? "moon.stars.fill" : "sun.max.fill"
        case 1, 2: return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
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

private struct WeatherRailLeadingPreference: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
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
            switch controller.state {
            case .fresh(let forecast): rail(for: forecast, staleAt: nil)
            case .stale(let forecast, let fetchedAt): rail(for: forecast, staleAt: fetchedAt)
            case .unavailable: unavailable
            case .noLocation: EmptyView()
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
                HStack(spacing: 5) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(verbatim: forecast.location.displayName)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let staleAt {
                        Text(verbatim: localization.format(
                            .weatherUpdatedFormat,
                            Self.updatedString(staleAt)
                        ))
                    }
                }
                .font(microFont)
                .foregroundStyle(microTextColor)

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
            ScrollViewReader { proxy in
                ZStack(alignment: .center) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                                WeatherPeriodCell(period: period, localization: localization)
                                    .frame(width: geometry.size.width / 4)
                                    .id(index)
                                    .background {
                                        GeometryReader { itemGeometry in
                                            Color.clear.preference(
                                                key: WeatherRailLeadingPreference.self,
                                                value: [index: itemGeometry.frame(in: .named("weather-rail")).minX]
                                            )
                                        }
                                    }
                            }
                        }
                    }
                    .coordinateSpace(name: "weather-rail")
                    .onPreferenceChange(WeatherRailLeadingPreference.self) { positions in
                        guard let nearest = positions.min(by: {
                            abs($0.value) < abs($1.value)
                        })?.key else { return }
                        firstVisibleIndex = nearest
                    }

                    HStack {
                        if firstVisibleIndex > 0 {
                            railArrow("chevron.left", title: localization.string(.previousMonth)) {
                                scroll(to: max(0, firstVisibleIndex - 1), proxy: proxy)
                            }
                        }
                        Spacer()
                        if firstVisibleIndex + 4 < periods.count {
                            railArrow("chevron.right", title: localization.string(.nextMonth)) {
                                scroll(to: min(periods.count - 4, firstVisibleIndex + 1), proxy: proxy)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 82)
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

    private func scroll(to index: Int, proxy: ScrollViewProxy) {
        let action = { proxy.scrollTo(index, anchor: .leading) }
        if reduceMotion { action() } else { withAnimation(.easeInOut(duration: 0.16), action) }
    }

    private static func updatedString(_ date: Date) -> String {
        DateFormatter.localizedString(
            from: date,
            dateStyle: .none,
            timeStyle: .short
        )
    }
}

struct WeatherPeriodCell: View {
    let period: WeatherDisplayPeriod
    let localization: QuickCalLocalization

    @Environment(\.quickCalThemeStyle) private var themeStyle

    var body: some View {
        let point = period.point
        VStack(spacing: 2) {
            Text(verbatim: timeString(point.timestamp))
                .font(measurementFont.weight(.semibold))
            Image(systemName: WeatherDisplayPeriod.symbol(for: point.weatherCode, at: point.timestamp))
                .font(.system(size: 16, weight: .medium))
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
            Rectangle().fill(themeStyle.dividerColor).frame(width: 1).padding(.vertical, 3)
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
