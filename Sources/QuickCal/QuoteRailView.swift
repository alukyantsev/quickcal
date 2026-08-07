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
                case .loading: loading
                case .unavailable: unavailable
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
            Text(verbatim: "MOEX")
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(themeStyle.secondaryText)
        .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
    }

    private var unavailable: some View {
        HStack(spacing: 7) {
            Image(systemName: "chart.line.downtrend.xyaxis")
            Text(verbatim: "MOEX недоступен")
            Spacer(minLength: 0)
            Button("Обновить") { refresh() }
                .buttonStyle(.plain)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(themeStyle.secondaryText)
        .padding(.top, themeStyle.usesWeekRules ? 5 : 3)
    }

    private func refresh() {
        if let onRefresh { onRefresh() } else { controller.refresh() }
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
