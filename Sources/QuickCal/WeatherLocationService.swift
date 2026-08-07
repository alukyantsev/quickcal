@preconcurrency import CoreLocation
import Foundation
import QuickCalKit

@MainActor
enum WeatherLocationAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

@MainActor
protocol WeatherLocationServicing: AnyObject {
    var authorizationStatus: WeatherLocationAuthorization { get }
    var authorizationStatusChanged: (@MainActor (WeatherLocationAuthorization) -> Void)? { get set }

    /// This is deliberately called only after the user explicitly enables automatic mode.
    func requestAuthorization()
    func currentLocation() async throws -> WeatherLocation
}

@MainActor
final class CoreLocationWeatherService: NSObject, WeatherLocationServicing {
    enum ServiceError: Error, Equatable {
        case locationUnavailable
        case locationRequestTimedOut
        case reverseGeocodingFailed
    }

    var authorizationStatusChanged: (@MainActor (WeatherLocationAuthorization) -> Void)?

    var authorizationStatus: WeatherLocationAuthorization {
        WeatherLocationAuthorization(manager.authorizationStatus)
    }

    private let manager: CLLocationManager
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationTimeoutTask: Task<Void, Never>?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func currentLocation() async throws -> WeatherLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw ServiceError.locationUnavailable
        }
        let location = try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
            locationTimeoutTask?.cancel()
            locationTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                self?.resumeLocationRequest(with: .failure(ServiceError.locationRequestTimedOut))
            }
        }
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw ServiceError.reverseGeocodingFailed
        }

        let displayName = placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? "Current Location"
        return WeatherLocation(
            displayName: displayName,
            administrativeArea: placemark.administrativeArea,
            country: placemark.country,
            countryCode: placemark.isoCountryCode,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}

extension CoreLocationWeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        notifyAuthorizationChange(for: manager)
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        notifyAuthorizationChange(for: manager)
    }

    private nonisolated func notifyAuthorizationChange(for manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            let status = WeatherLocationAuthorization(manager.authorizationStatus)
            self?.authorizationStatusChanged?(status)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            return
        }
        Task { @MainActor [weak self] in
            self?.resumeLocationRequest(with: .success(location))
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.resumeLocationRequest(with: .failure(error))
        }
    }
}

@MainActor
private extension CoreLocationWeatherService {
    func resumeLocationRequest(with result: Result<CLLocation, Error>) {
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil
        let continuation = locationContinuation
        locationContinuation = nil
        continuation?.resume(with: result)
    }
}

private extension WeatherLocationAuthorization {
    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .restricted
        }
    }
}
