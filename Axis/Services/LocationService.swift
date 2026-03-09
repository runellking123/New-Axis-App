import CoreLocation
import Foundation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var currentLocationName: String = ""
    private(set) var isUsingCustomLocation: Bool = false
    private(set) var customLocation: CLLocation?

    /// The effective location used for searches (custom or GPS)
    var effectiveLocation: CLLocation? {
        isUsingCustomLocation ? customLocation : currentLocation
    }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
        currentLocation = manager.location
        if let currentLocation {
            reverseGeocode(currentLocation)
        }
    }

    func requestPermission() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            requestLocation()
            return
        }
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        manager.requestLocation()
    }

    /// Forward geocode a city/address query and set it as the custom location
    func searchCity(_ query: String) async -> Bool {
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            guard let placemark = placemarks.first, let location = placemark.location else {
                return false
            }
            await MainActor.run {
                self.customLocation = location
                self.isUsingCustomLocation = true
                self.currentLocationName = Self.formatPlacemark(placemark)
            }
            return true
        } catch {
            #if DEBUG
            print("[LocationService] Geocode error: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Revert to using the GPS location
    func resetToCurrentLocation() {
        isUsingCustomLocation = false
        customLocation = nil
        if let location = currentLocation {
            reverseGeocode(location)
        }
        requestLocation()
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                if let placemark = placemarks?.first {
                    self?.currentLocationName = Self.formatPlacemark(placemark)
                }
            }
        }
    }

    private static func formatPlacemark(_ placemark: CLPlacemark) -> String {
        let city = placemark.locality ?? ""
        let state = placemark.administrativeArea ?? ""
        if !city.isEmpty && !state.isEmpty {
            return "\(city), \(state)"
        }
        return city.isEmpty ? state : city
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.currentLocation = locations.last
            if !self.isUsingCustomLocation, let location = locations.last {
                self.reverseGeocode(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("[LocationService] Location error: \(error.localizedDescription)")
        #endif
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}
