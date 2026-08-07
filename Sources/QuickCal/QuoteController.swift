import Combine
import Foundation
import QuickCalKit

@MainActor
enum QuotePresentationState: Equatable {
    case idle
    case loading
    case fresh(MarketQuoteSnapshot, fetchedAt: Date)
    case unavailable
}

@MainActor
final class QuoteController: ObservableObject {
    @Published private(set) var settings: MarketQuoteSettings
    @Published private(set) var state: QuotePresentationState
    @Published private(set) var isRefreshing = false

    var lastFetchedAt: Date? {
        if case .fresh(_, let fetchedAt) = state { return fetchedAt }
        return nil
    }

    private let settingsStore: MarketQuoteSettingsStore
    private let cacheStore: MarketQuoteCacheStore
    private let provider: any MarketQuoteProviding
    private let now: @Sendable () -> Date
    private var refreshTask: Task<Void, Never>?

    init(
        settingsStore: MarketQuoteSettingsStore = MarketQuoteSettingsStore(),
        cacheStore: MarketQuoteCacheStore = MarketQuoteCacheStore(),
        provider: any MarketQuoteProviding,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.settingsStore = settingsStore
        self.cacheStore = cacheStore
        self.provider = provider
        self.now = now
        settings = settingsStore.settings
        state = .idle
        updatePresentationFromCache()
    }

    deinit {
        refreshTask?.cancel()
    }

    func setVisibility(_ isVisible: Bool) {
        let updated = MarketQuoteSettings(isVisible: isVisible, tickers: settings.tickers)
        settings = updated
        settingsStore.update(updated)
        updatePresentationFromCache()
        if isVisible { refresh() }
    }

    func refresh() {
        guard settings.isVisible, refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer { self.refreshTask = nil }
            await self.performRefresh()
        }
    }

    func refreshNow() async {
        guard settings.isVisible else { return }
        if let refreshTask {
            await refreshTask.value
            return
        }
        await performRefresh()
    }

    private func performRefresh() async {
        isRefreshing = true
        state = .loading
        defer { isRefreshing = false }

        var quotes: [MarketQuote] = []
        for ticker in settings.tickers {
            if let quote = try? await provider.quote(for: ticker) {
                quotes.append(quote)
            }
        }
        guard !quotes.isEmpty else {
            updatePresentationFromCache()
            return
        }

        let fetchedAt = now()
        let snapshot = MarketQuoteSnapshot(quotes: quotes)
        cacheStore.save(MarketQuoteCacheEntry(snapshot: snapshot, fetchedAt: fetchedAt))
        state = .fresh(snapshot, fetchedAt: fetchedAt)
    }

    private func updatePresentationFromCache() {
        guard settings.isVisible else {
            state = .idle
            return
        }
        guard let entry = cacheStore.load(), entry.isUsable(at: now()) else {
            state = .unavailable
            return
        }
        state = .fresh(entry.snapshot, fetchedAt: entry.fetchedAt)
    }
}

@MainActor
final class ForegroundRefreshCoordinator {
    static let interval: TimeInterval = 30 * 60

    private let weatherController: WeatherController
    private let quoteController: QuoteController
    private let timer: any ForegroundRefreshScheduling

    init(
        weatherController: WeatherController,
        quoteController: QuoteController,
        timer: any ForegroundRefreshScheduling = RunLoopForegroundRefreshTimer()
    ) {
        self.weatherController = weatherController
        self.quoteController = quoteController
        self.timer = timer
    }

    func start() {
        timer.schedule(every: Self.interval) { [weak self] in
            self?.refresh()
        }
    }

    func stop() {
        timer.invalidate()
    }

    func refresh() {
        weatherController.refresh()
        quoteController.refresh()
    }

    func refreshNow() async {
        async let weather: Void = weatherController.refreshNow()
        async let quotes: Void = quoteController.refreshNow()
        _ = await (weather, quotes)
    }
}
