import SwiftUI
import QuickCalKit

@MainActor
struct QuoteRailView: View {
    private enum Column {
        static let price: CGFloat = 66
        static let absoluteChange: CGFloat = 70
        static let percentageChange: CGFloat = 60
    }

    @ObservedObject var controller: QuoteController
    var onRefresh: (() -> Void)?

    @Environment(\.quickCalThemeStyle) private var themeStyle

    private let localization = QuickCalLocalization.current

    var body: some View {
        Group {
            if controller.settings.isVisible {
                switch controller.state {
                case .fresh(let snapshot, _): quoteRows(snapshot.quotes)
                case .stale(let snapshot, let fetchedAt, let failedTickers):
                    quoteRows(snapshot.quotes)
                    staleNotice(fetchedAt: fetchedAt, failedTickers: failedTickers)
                case .partial(let snapshot, let fetchedAt, let failedTickers):
                    quoteRows(snapshot.quotes)
                    partialNotice(fetchedAt: fetchedAt, failedTickers: failedTickers)
                case .loading: loading
                case .error(let failedTickers): unavailable(failedTickers: failedTickers)
                case .empty: empty
                case .idle: EmptyView()
                }
            } else {
                EmptyView()
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func quoteRows(_ quotes: [MarketQuote]) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(themeStyle.dividerColor)
                .frame(height: 1)
                .padding(.bottom, 3)
            ForEach(quotes, id: \.ticker) { quote in
                quoteRow(quote)
            }
            if quotes.allSatisfy({ $0.dataDate != nil }),
               let dataDate = quotes.compactMap(\.dataDate).max()
            {
                Text(verbatim: localization.format(.marketDataAsOfFormat, dataDateString(dataDate)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(themeStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                    .accessibilityLabel(Text(verbatim: localization.format(
                        .marketDataDateAccessibilityFormat,
                        dataDateString(dataDate)
                    )))
            } else {
                Text(verbatim: localization.string(.marketDataDateUnavailable))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(themeStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                    .accessibilityLabel(Text(verbatim: localization.string(.marketDataDateUnavailable)))
            }
        }
        .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
    }

    private func quoteRow(_ quote: MarketQuote) -> some View {
        let direction = quote.change == 0 ? "→" : quote.change > 0 ? "↑" : "↓"
        let directionAccessibility = quote.change == 0
            ? localization.string(.marketDirectionUnchanged)
            : quote.change > 0
                ? localization.string(.marketDirectionUp)
                : localization.string(.marketDirectionDown)
        let change = String(
            format: "%@%.2f%%",
            locale: localization.locale,
            quote.change >= 0 ? "+" : "",
            quote.changePercent
        )
        let absoluteChange = Self.signedChangeString(
            quote.change,
            maximumFractionDigits: quote.price < 10 ? 4 : 2,
            locale: localization.locale
        )
        return HStack(spacing: 0) {
            Text(verbatim: quote.displayName)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: Self.priceString(quote.price))
                .monospacedDigit()
                .frame(width: Column.price, alignment: .trailing)
            Text(verbatim: "\(direction) \(absoluteChange)")
                .monospacedDigit()
                .foregroundStyle(changeColor(for: quote.change))
                .frame(width: Column.absoluteChange, alignment: .trailing)
            Text(verbatim: change)
                .monospacedDigit()
                .foregroundStyle(changeColor(for: quote.change))
                .frame(width: Column.percentageChange, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium, design: themeStyle.layout == .instrumentGrid ? .monospaced : .default))
        .foregroundStyle(themeStyle.primaryText)
        .frame(maxWidth: .infinity, minHeight: 20)
        .padding(.horizontal, 2)
        .accessibilityLabel(Text(verbatim: localization.format(
            .marketQuoteAccessibilityFormat,
            quote.displayName,
            Self.priceString(quote.price),
            directionAccessibility,
            absoluteChange,
            change,
            quote.dataDate.map(dataDateString) ?? localization.string(.marketDataDateUnavailable)
        )))
    }

    private var loading: some View {
        HStack(spacing: 7) {
            ProgressView().controlSize(.small)
            Text(verbatim: localization.string(.marketLoading))
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(themeStyle.secondaryText)
        .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
        .accessibilityLabel(Text(verbatim: localization.string(.marketLoading)))
    }

    private func unavailable(failedTickers: [String]) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "chart.line.downtrend.xyaxis")
            Text(verbatim: localization.string(.marketUnavailable))
            Spacer(minLength: 0)
            retryButton
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(themeStyle.secondaryText)
        .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: errorAccessibilityText(for: failedTickers)))
    }

    private var empty: some View {
        HStack(spacing: 7) {
            Text(verbatim: localization.string(.marketEmpty))
                .lineLimit(1)
            Spacer(minLength: 0)
            retryButton
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(themeStyle.secondaryText)
        .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: localization.string(.marketEmptyAccessibility)))
    }

    private func staleNotice(fetchedAt: Date, failedTickers: [String]) -> some View {
        notice(
            localization.format(.marketStaleFormat, dataDateString(fetchedAt)),
            accessibility: failedTickers.isEmpty
                ? localization.format(.marketStaleAccessibilityFormat, dataDateString(fetchedAt))
                : "\(localization.format(.marketStaleAccessibilityFormat, dataDateString(fetchedAt))) \(errorAccessibilityText(for: failedTickers))"
        )
    }

    private func partialNotice(fetchedAt: Date, failedTickers: [String]) -> some View {
        notice(
            localization.format(.marketPartialFormat, failedTickers.joined(separator: ", ")),
            accessibility: localization.format(
                .marketPartialAccessibilityFormat,
                errorAccessibilityText(for: failedTickers),
                dataDateString(fetchedAt)
            )
        )
    }

    private func notice(_ text: String, accessibility: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10, weight: .semibold))
            Text(verbatim: text)
                .lineLimit(2)
            Spacer(minLength: 0)
            retryButton
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(themeStyle.secondaryText)
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: accessibility))
    }

    private var retryButton: some View {
        Button(localization.string(.marketRetry)) { refresh() }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: localization.string(.marketRetryAccessibility)))
            .accessibilityHint(Text(verbatim: localization.string(.marketRetryHint)))
    }

    private func refresh() {
        if let onRefresh { onRefresh() } else { controller.refresh() }
    }

    private func errorAccessibilityText(for failedTickers: [String]) -> String {
        guard !failedTickers.isEmpty else { return localization.string(.marketErrorAccessibility) }
        return localization.format(
            .marketFailedTickersAccessibilityFormat,
            failedTickers.joined(separator: ", ")
        )
    }

    private func changeColor(for change: Double) -> Color {
        if change > 0 { return .green }
        if change < 0 { return .red }
        return themeStyle.secondaryText
    }

    private static func priceString(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    private static func signedChangeString(
        _ change: Double,
        maximumFractionDigits: Int,
        locale: Locale
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = maximumFractionDigits
        formatter.locale = locale
        let value = formatter.string(from: NSNumber(value: abs(change))) ?? "\(abs(change))"
        return "\(change >= 0 ? "+" : "−")\(value)"
    }

    private func dataDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
