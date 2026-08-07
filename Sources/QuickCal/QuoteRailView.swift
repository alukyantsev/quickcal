import SwiftUI
import QuickCalKit

@MainActor
struct QuoteRailView: View {
    @ObservedObject var controller: QuoteController
    var onRefresh: (() -> Void)?

    @Environment(\.quickCalThemeStyle) private var themeStyle

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
            if let dataDate = quotes.map(\.dataDate).max() {
                Text(verbatim: "Данные на \(Self.dataDateString(dataDate))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(themeStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                    .accessibilityLabel(Text(verbatim: "Дата рыночных данных: \(Self.dataDateString(dataDate))"))
            }
        }
        .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
    }

    private func quoteRow(_ quote: MarketQuote) -> some View {
        let direction = quote.change == 0 ? "→" : quote.change > 0 ? "↑" : "↓"
        let change = String(format: "%@%.2f%%", quote.change >= 0 ? "+" : "", quote.changePercent)
        return HStack(spacing: 6) {
            Text(verbatim: quote.displayName)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(verbatim: Self.priceString(quote.price))
                .monospacedDigit()
            Text(verbatim: "\(direction) \(change)")
                .monospacedDigit()
                .foregroundStyle(changeColor(for: quote.change))
                .frame(minWidth: 62, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium, design: themeStyle.layout == .instrumentGrid ? .monospaced : .default))
        .foregroundStyle(themeStyle.primaryText)
        .frame(maxWidth: .infinity, minHeight: 20)
        .padding(.horizontal, 2)
        .accessibilityLabel(Text(verbatim: "\(quote.displayName), \(Self.priceString(quote.price)), \(direction) \(String(format: "%.2f", quote.change)), \(change), \(Self.dataDateString(quote.dataDate))"))
    }

    private var loading: some View {
        HStack(spacing: 7) {
            ProgressView().controlSize(.small)
            Text(verbatim: "Загрузка котировок MOEX")
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(themeStyle.secondaryText)
        .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
        .accessibilityLabel(Text(verbatim: "Загрузка котировок MOEX"))
    }

    private func unavailable(failedTickers: [String]) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "chart.line.downtrend.xyaxis")
            Text(verbatim: "MOEX недоступен")
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
            Text(verbatim: "Добавьте тикеры в настройках")
                .lineLimit(1)
            Spacer(minLength: 0)
            retryButton
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(themeStyle.secondaryText)
        .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "Список котировок пуст. Добавьте тикеры в настройках котировок или повторите обновление."))
    }

    private func staleNotice(fetchedAt: Date, failedTickers: [String]) -> some View {
        notice(
            "Показаны сохранённые данные от \(Self.dataDateString(fetchedAt))",
            accessibility: failedTickers.isEmpty
                ? "Показаны устаревшие сохранённые данные от \(Self.dataDateString(fetchedAt))."
                : "Показаны устаревшие сохранённые данные. \(errorAccessibilityText(for: failedTickers))"
        )
    }

    private func partialNotice(fetchedAt: Date, failedTickers: [String]) -> some View {
        notice(
            "Не загружены: \(failedTickers.joined(separator: ", "))",
            accessibility: "Часть котировок загружена. \(errorAccessibilityText(for: failedTickers)) Данные обновлены \(Self.dataDateString(fetchedAt))."
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
        Button("Обновить") { refresh() }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: "Повторить загрузку котировок MOEX"))
            .accessibilityHint(Text(verbatim: "Повторно загружает котировки из MOEX"))
    }

    private func refresh() {
        if let onRefresh { onRefresh() } else { controller.refresh() }
    }

    private func errorAccessibilityText(for failedTickers: [String]) -> String {
        guard !failedTickers.isEmpty else { return "Котировки MOEX недоступны." }
        return "Не удалось загрузить тикеры: \(failedTickers.joined(separator: ", "))."
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

    private static func dataDateString(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
    }
}
