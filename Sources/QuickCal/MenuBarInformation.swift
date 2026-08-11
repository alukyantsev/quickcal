import AppKit
import Foundation
import QuickCalKit

@MainActor
struct MenuBarInformationPresentation: Equatable {
    struct Weather: Equatable {
        let systemImage: String
        let temperature: String
        let staleAt: Date?

        var isStale: Bool { staleAt != nil }

        init(
            systemImage: String,
            temperature: String,
            staleAt: Date? = nil
        ) {
            self.systemImage = systemImage
            self.temperature = temperature
            self.staleAt = staleAt
        }
    }

    struct Quote: Equatable {
        static let systemImage = "chart.line.uptrend.xyaxis"

        let value: String
        let staleAt: Date?

        var text: String { value }
        var isStale: Bool { staleAt != nil }

        init(value: String, staleAt: Date? = nil) {
            self.value = value
            self.staleAt = staleAt
        }
    }

    let weather: Weather?
    let quote: Quote?
    let accessibilityLabel: String
    let toolTip: String

    var title: String {
        [weather?.temperature, quote?.text]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var isDetailed: Bool {
        weather != nil || quote != nil
    }

    static func make(
        isEnabled: Bool,
        weatherIsVisible: Bool,
        weatherState: WeatherPresentationState,
        quoteIsVisible: Bool,
        quoteState: QuotePresentationState,
        now: Date = Date(),
        localization: QuickCalLocalization = .current,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> MenuBarInformationPresentation {
        guard isEnabled else {
            return fallback
        }

        let weather = weatherIsVisible
            ? weatherPresentation(
                from: weatherState,
                now: now,
                localization: localization,
                timeZone: timeZone
            )
            : nil
        let quote = quoteIsVisible
            ? quotePresentation(from: quoteState)
            : nil

        guard weather != nil || quote != nil else {
            return fallback
        }

        let details = accessibilityDetails(
            weather: weather,
            quote: quote,
            localization: localization,
            timeZone: timeZone
        )
        let accessibilityLabel = localization.format(
            .menuBarAccessibilityFormat,
            details
        )
        return MenuBarInformationPresentation(
            weather: weather,
            quote: quote,
            accessibilityLabel: accessibilityLabel,
            toolTip: accessibilityLabel
        )
    }

    private static let fallback = MenuBarInformationPresentation(
        weather: nil,
        quote: nil,
        accessibilityLabel: "QuickCal",
        toolTip: "QuickCal"
    )

    private static func weatherPresentation(
        from state: WeatherPresentationState,
        now: Date,
        localization: QuickCalLocalization,
        timeZone: TimeZone
    ) -> Weather? {
        let forecast: WeatherForecast
        let staleAt: Date?
        switch state {
        case .fresh(let value):
            forecast = value
            staleAt = nil
        case .stale(let value, let fetchedAt):
            forecast = value
            staleAt = fetchedAt
        case .noLocation, .unavailable:
            return nil
        }

        guard let point = forecast.hourly
            .sorted(by: { $0.timestamp < $1.timestamp })
            .first(where: { $0.timestamp >= now })
        else {
            return nil
        }

        return Weather(
            systemImage: WeatherDisplayPeriod.symbol(
                for: point.weatherCode,
                at: point.timestamp,
                timeZone: timeZone
            ),
            temperature: String(
                format: "%+.0f°",
                locale: localization.locale,
                point.temperatureCelsius
            ),
            staleAt: staleAt
        )
    }

    private static func quotePresentation(
        from state: QuotePresentationState
    ) -> Quote? {
        let snapshot: MarketQuoteSnapshot
        let staleAt: Date?
        switch state {
        case .fresh(let value, _), .partial(let value, _, _):
            snapshot = value
            staleAt = nil
        case .stale(let value, let fetchedAt, _):
            snapshot = value
            staleAt = fetchedAt
        case .idle, .loading, .error, .empty:
            return nil
        }

        guard let quote = snapshot.quotes.first(where: {
            $0.ticker.caseInsensitiveCompare("IMOEX") == .orderedSame
        }) else {
            return nil
        }

        let price = String(Int(quote.price.rounded()))
        return Quote(
            value: price,
            staleAt: staleAt
        )
    }

    private static func accessibilityDetails(
        weather: Weather?,
        quote: Quote?,
        localization: QuickCalLocalization,
        timeZone: TimeZone
    ) -> String {
        var parts: [String] = []
        if let weather {
            if let staleAt = weather.staleAt {
                parts.append(localization.format(
                    .menuBarWeatherStaleFormat,
                    weather.temperature,
                    staleDateString(
                        staleAt,
                        localization: localization,
                        timeZone: timeZone
                    )
                ))
            } else {
                parts.append(localization.format(
                    .menuBarWeatherFormat,
                    weather.temperature
                ))
            }
        }
        if let quote {
            if let staleAt = quote.staleAt {
                parts.append(localization.format(
                    .menuBarIMOEXStaleFormat,
                    quote.value,
                    staleDateString(
                        staleAt,
                        localization: localization,
                        timeZone: timeZone
                    )
                ))
            } else {
                parts.append(localization.format(
                    .menuBarIMOEXFormat,
                    quote.value
                ))
            }
        }
        return parts.joined(separator: " ")
    }

    private static func staleDateString(
        _ date: Date,
        localization: QuickCalLocalization,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@MainActor
enum MenuBarStatusItemRenderer {
    static let preferredLength = NSStatusItem.variableLength

    static func apply(
        presentation: MenuBarInformationPresentation,
        to button: NSStatusBarButton
    ) {
        if presentation.isDetailed {
            applyDetailed(presentation, to: button)
        } else {
            applyFallback(to: button)
        }
        button.setAccessibilityLabel(presentation.accessibilityLabel)
        button.toolTip = presentation.toolTip
    }

    private static func applyDetailed(
        _ presentation: MenuBarInformationPresentation,
        to button: NSStatusBarButton
    ) {
        button.title = ""
        button.attributedTitle = attributedTitle(for: presentation)
        button.imageScaling = .scaleNone

        if let weather = presentation.weather {
            button.image = symbolImage(
                named: weather.systemImage,
                pointSize: 14
            )
            button.imagePosition = .imageLeading
            button.contentTintColor = nil
        } else {
            button.image = nil
            button.imagePosition = .noImage
            button.contentTintColor = nil
        }
    }

    private static func applyFallback(to button: NSStatusBarButton) {
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.image = symbolImage(
            named: "calendar.badge.clock",
            pointSize: 18
        )
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.contentTintColor = nil
    }

    private static func attributedTitle(
        for presentation: MenuBarInformationPresentation
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if let weather = presentation.weather {
            result.append(fragment(
                weather.temperature,
                color: weather.isStale ? .secondaryLabelColor : nil
            ))
        }
        if presentation.weather != nil, presentation.quote != nil {
            result.append(fragment(" · ", color: .secondaryLabelColor))
        }
        if let quote = presentation.quote {
            result.append(symbolAttachment(
                named: MenuBarInformationPresentation.Quote.systemImage
            ))
            result.append(fragment("\u{00A0}", color: nil))
            result.append(fragment(
                quote.text,
                color: quote.isStale ? .secondaryLabelColor : nil
            ))
        }
        return result
    }

    private static func fragment(
        _ string: String,
        color: NSColor?
    ) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize,
                weight: .medium
            ),
        ]
        if let color {
            attributes[.foregroundColor] = color
        }
        return NSAttributedString(
            string: string,
            attributes: attributes
        )
    }

    private static func symbolAttachment(named name: String) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = symbolImage(
            named: name,
            pointSize: 14,
            weight: .semibold
        )
        attachment.bounds = NSRect(x: 0, y: -2, width: 14, height: 14)
        return NSAttributedString(attachment: attachment)
    }

    private static func symbolImage(
        named name: String,
        pointSize: CGFloat,
        weight: NSFont.Weight = .medium
    ) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: weight
        )
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }
}

@MainActor
enum MenuBarPopoverLayout {
    // The status item must retain its native width so opening the popover
    // cannot resize its icon. This virtual rect keeps the popover anchored to
    // the item's stable trailing edge as the detailed title comes and goes.
    static let anchorWidth: CGFloat = 168

    static func positioningRect(in bounds: NSRect) -> NSRect {
        NSRect(
            x: bounds.maxX - anchorWidth,
            y: bounds.minY,
            width: anchorWidth,
            height: bounds.height
        )
    }
}
