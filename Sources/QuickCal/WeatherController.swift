import Combine
import Foundation
import QuickCalKit

@MainActor
protocol WeatherRefreshScheduling: AnyObject {
    func schedule(
        every interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    )
    func invalidate()
}

@MainActor
final class RunLoopWeatherRefreshTimer: WeatherRefreshScheduling {
    private var timer: Timer?

    func schedule(
        every interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) {
        invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                action()
            }
        }
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}

@MainActor
enum WeatherPresentationState: Equatable {
    case noLocation
    case fresh(WeatherForecast)
    case stale(WeatherForecast, fetchedAt: Date)
    case unavailable
}

@MainActor
struct WeatherHeaderContext: Equatable {
    let location: WeatherLocation
    let fetchedAt: Date
}

@MainActor
enum AutomaticLocationStatus: Equatable {
    case inactive
    case awaitingAuthorization
    case locating
    case unavailable
}

@MainActor
final class WeatherController: ObservableObject {
    static let foregroundRefreshInterval: TimeInterval = 30 * 60
    static let freshCacheLifetime: TimeInterval = 30 * 60
    static let staleCacheLifetime: TimeInterval = 24 * 60 * 60

    @Published private(set) var state: WeatherPresentationState
    @Published private(set) var settings: WeatherSettings
    @Published private(set) var isRefreshing = false
    @Published private(set) var automaticLocationStatus: AutomaticLocationStatus = .inactive
    @Published private(set) var lastForecastFetchedAt: Date?

    var headerContext: WeatherHeaderContext? {
        guard settings.isVisible else { return nil }
        switch state {
        case .fresh(let forecast):
            return WeatherHeaderContext(
                location: forecast.location,
                fetchedAt: lastForecastFetchedAt ?? now()
            )
        case .stale(let forecast, let fetchedAt):
            return WeatherHeaderContext(location: forecast.location, fetchedAt: fetchedAt)
        case .noLocation, .unavailable:
            return nil
        }
    }

    private let settingsStore: WeatherSettingsStore
    private let cacheStore: WeatherForecastCacheStore
    private let provider: any WeatherForecastProviding
    private let locationService: any WeatherLocationServicing
    private let timer: any WeatherRefreshScheduling
    private let now: @Sendable () -> Date
    private var refreshTask: Task<Void, Never>?

    init(
        settingsStore: WeatherSettingsStore = WeatherSettingsStore(),
        cacheStore: WeatherForecastCacheStore = WeatherForecastCacheStore(),
        provider: any WeatherForecastProviding,
        locationService: any WeatherLocationServicing,
        timer: any WeatherRefreshScheduling = RunLoopWeatherRefreshTimer(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.settingsStore = settingsStore
        self.cacheStore = cacheStore
        self.provider = provider
        self.locationService = locationService
        self.timer = timer
        self.now = now
        settings = settingsStore.settings
        state = .noLocation
        updatePresentationFromCache()
        locationService.authorizationStatusChanged = { [weak self] status in
            self?.handleLocationAuthorizationChange(status)
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    func startForegroundRefresh() {
        timer.schedule(every: Self.foregroundRefreshInterval) { [weak self] in
            self?.refreshFromForegroundTimer()
        }
    }

    func stopForegroundRefresh() {
        timer.invalidate()
    }

    func setManualLocation(_ location: WeatherLocation?) {
        var updated = settings
        updated.locationMode = .manual
        updated.manualLocation = location
        persist(updated)
        refresh()
    }

    func setAutomaticModeEnabled(_ isEnabled: Bool) {
        var updated = settings
        if isEnabled {
            updated.locationMode = .automatic
        } else {
            // Leaving automatic mode keeps the last resolved automatic city
            // as the active manual fallback until the user chooses a city.
            updated.locationMode = .manual
            updated.manualLocation = updated.automaticLocation ?? updated.manualLocation
        }
        persist(updated)

        guard isEnabled else {
            automaticLocationStatus = .inactive
            refresh()
            return
        }
        requestAutomaticLocationIfAuthorized()
    }

    func retryAutomaticLocation() {
        guard settings.locationMode == .automatic else { return }
        requestAutomaticLocationIfAuthorized()
    }

    func setVisibility(_ isVisible: Bool) {
        var updated = settings
        updated.isVisible = isVisible
        persist(updated)
    }

    func setInterval(_ interval: WeatherInterval) {
        guard settings.interval != interval else { return }
        var updated = settings
        updated.interval = interval
        persist(updated)
    }

    func searchLocations(query: String) async -> [WeatherLocation] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }
        return (try? await provider.searchLocations(query: normalizedQuery)) ?? []
    }

    func refresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer { self.refreshTask = nil }
            await self.performRefresh()
        }
    }

    func refreshNow() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        await performRefresh()
    }

    func handleLocationAuthorizationChange(_ status: WeatherLocationAuthorization) {
        guard settings.locationMode == .automatic else { return }
        switch status {
        case .authorized:
            automaticLocationStatus = .locating
            refresh()
        case .notDetermined:
            break
        case .denied, .restricted:
            automaticLocationStatus = .unavailable
            refreshFallbackForecast()
        }
    }

    private func refreshFromForegroundTimer() {
        refresh()
    }

    private func requestAutomaticLocationIfAuthorized() {
        switch locationService.authorizationStatus {
        case .notDetermined:
            automaticLocationStatus = .awaitingAuthorization
            locationService.requestAuthorization()
            updatePresentationFromCache()
        case .authorized:
            automaticLocationStatus = .locating
            refresh()
        case .denied, .restricted:
            automaticLocationStatus = .unavailable
            refreshFallbackForecast()
        }
    }

    private func refreshFallbackForecast() {
        guard settings.resolvedLocation != nil else {
            updatePresentationFromCache()
            return
        }
        refresh()
    }

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        var location = settings.resolvedLocation
        if settings.locationMode == .automatic,
           locationService.authorizationStatus == .authorized
        {
            do {
                let automaticLocation = try await locationService.currentLocation()
                var updated = settings
                updated.automaticLocation = automaticLocation
                persist(updated)
                automaticLocationStatus = .inactive
                location = automaticLocation
            } catch {
                // A previous automatic or manual selection remains the fallback,
                // but the options UI must not present that fallback as a success.
                automaticLocationStatus = .unavailable
                location = settings.resolvedLocation
            }
        }

        guard let location else {
            updatePresentationFromCache()
            return
        }

        do {
            let forecast = try await provider.forecast(for: location)
            let fetchedAt = now()
            cacheStore.save(WeatherForecastCacheEntry(forecast: forecast, fetchedAt: fetchedAt))
            lastForecastFetchedAt = fetchedAt
            state = .fresh(forecast)
        } catch {
            updatePresentationFromCache()
        }
    }

    private func persist(_ settings: WeatherSettings) {
        self.settings = settings
        settingsStore.update(settings)
        updatePresentationFromCache()
    }

    private func updatePresentationFromCache() {
        guard let location = settings.resolvedLocation else {
            lastForecastFetchedAt = nil
            state = .noLocation
            return
        }
        guard
            let entry = cacheStore.load(),
            entry.forecast.location == location
        else {
            lastForecastFetchedAt = nil
            state = .unavailable
            return
        }

        let age = max(0, now().timeIntervalSince(entry.fetchedAt))
        lastForecastFetchedAt = entry.fetchedAt
        if age < Self.freshCacheLifetime {
            state = .fresh(entry.forecast)
        } else if age <= Self.staleCacheLifetime {
            state = .stale(entry.forecast, fetchedAt: entry.fetchedAt)
        } else {
            state = .unavailable
        }
    }
}
