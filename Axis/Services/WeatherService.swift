import CoreLocation
import Foundation

@Observable
final class WeatherService {
    static let shared = WeatherService()

    private(set) var currentWeather: WeatherData?
    private(set) var isLoading = false
    private(set) var lastErrorMessage: String?
    private(set) var lastUpdatedAt: Date?

    struct WeatherData: Equatable {
        let temperature: Double
        let condition: String
        let icon: String // SF Symbol name directly
        let humidity: Int
        let feelsLike: Double
        let location: String
        let actionableNote: String

        var temperatureFormatted: String {
            "\(Int(temperature))°"
        }

        var sfSymbol: String { icon }
    }

    private init() {}

    func fetchWeather() async -> WeatherData? {
        let cachedWeather = await MainActor.run { currentWeather }
        let alreadyLoading = await MainActor.run { isLoading }
        if alreadyLoading {
            return cachedWeather
        }

        if let cachedWeather,
           let lastUpdatedAt = await MainActor.run(body: { self.lastUpdatedAt }),
           Date().timeIntervalSince(lastUpdatedAt) < 900 {
            return cachedWeather
        }

        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        guard let location = await resolveLocation() else {
            let authStatus = await MainActor.run { LocationService.shared.authorizationStatus }
            let statusLabel: String
            switch authStatus {
            case .notDetermined: statusLabel = "not determined"
            case .denied: statusLabel = "denied"
            case .restricted: statusLabel = "restricted"
            case .authorizedWhenInUse: statusLabel = "authorized (GPS timeout)"
            case .authorizedAlways: statusLabel = "authorized always (GPS timeout)"
            @unknown default: statusLabel = "unknown"
            }
            await MainActor.run {
                self.lastErrorMessage = "Location unavailable — \(statusLabel). Pull down to retry."
            }
            return cachedWeather
        }

        do {
            let data = try await fetchFromOpenMeteo(location: location)

            await MainActor.run {
                self.lastErrorMessage = nil
                self.currentWeather = data
                self.lastUpdatedAt = Date()
            }
            return data
        } catch {
            await MainActor.run {
                self.lastErrorMessage = "Weather fetch failed: \(error.localizedDescription)"
            }
            return cachedWeather
        }
    }

    // MARK: - Open-Meteo API (free, no API key)

    private func fetchFromOpenMeteo(location: CLLocation) async throws -> WeatherData {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let current = json["current"] as! [String: Any]

        let temp = (current["temperature_2m"] as? Double) ?? 0
        let feelsLike = (current["apparent_temperature"] as? Double) ?? temp
        let humidity = (current["relative_humidity_2m"] as? Int) ?? 0
        let weatherCode = (current["weather_code"] as? Int) ?? 0
        let isDay = (current["is_day"] as? Int) ?? 1

        let conditionText = Self.conditionText(for: weatherCode)
        let symbol = Self.sfSymbol(for: weatherCode, isDay: isDay == 1)
        let locationName = await resolveLocationName(for: location)

        return WeatherData(
            temperature: temp,
            condition: conditionText,
            icon: symbol,
            humidity: humidity,
            feelsLike: feelsLike,
            location: locationName,
            actionableNote: generateActionableNote(temp: temp, condition: conditionText)
        )
    }

    // MARK: - WMO Weather Code Mapping

    private static func conditionText(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with Hail"
        default: return "Unknown"
        }
    }

    private static func sfSymbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1:
            return isDay ? "sun.min.fill" : "moon.fill"
        case 2:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55:
            return "cloud.drizzle.fill"
        case 56, 57:
            return "cloud.sleet.fill"
        case 61, 63, 65:
            return "cloud.rain.fill"
        case 66, 67:
            return "cloud.sleet.fill"
        case 71, 73, 75, 77:
            return "cloud.snow.fill"
        case 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }

    // MARK: - Location

    private func resolveLocation() async -> CLLocation? {
        let locationService = await MainActor.run { LocationService.shared }

        // Check for existing location first
        if let existing = await MainActor.run(body: { locationService.effectiveLocation }) {
            return existing
        }

        // Check cached CLLocationManager location
        if let cached = await MainActor.run(body: { locationService.currentLocation }) {
            return cached
        }

        // Request permission if needed
        let status = await MainActor.run { locationService.authorizationStatus }
        if status == .notDetermined {
            await MainActor.run { locationService.requestPermission() }
            for _ in 0..<20 {
                let s = await MainActor.run { locationService.authorizationStatus }
                if s == .authorizedWhenInUse || s == .authorizedAlways { break }
                if s == .denied || s == .restricted { return nil }
                try? await Task.sleep(for: .milliseconds(500))
            }
        } else if status == .denied || status == .restricted {
            return nil
        }

        // Request a fresh location fix
        await MainActor.run { locationService.requestLocation() }

        // Wait up to 15 seconds for GPS fix
        for _ in 0..<30 {
            if let loc = await MainActor.run(body: {
                locationService.effectiveLocation ?? locationService.currentLocation
            }) {
                return loc
            }
            try? await Task.sleep(for: .milliseconds(500))
        }

        return nil
    }

    private func resolveLocationName(for location: CLLocation) async -> String {
        let locationService = LocationService.shared
        let customLocationName = await MainActor.run { locationService.currentLocationName }
        if !customLocationName.isEmpty {
            return customLocationName
        }
        return await reverseGeocode(location)
    }

    private func reverseGeocode(_ location: CLLocation) async -> String {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                return [placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
            }
        } catch { }
        return "Current Location"
    }

    private func generateActionableNote(temp: Double, condition: String) -> String {
        let lower = condition.lowercased()
        if lower.contains("rain") || lower.contains("drizzle") {
            return "Rain expected — grab an umbrella."
        } else if lower.contains("thunderstorm") {
            return "Storms today — consider indoor plans."
        } else if lower.contains("snow") {
            return "Snow — allow extra drive time."
        } else if lower.contains("clear") && temp > 90 {
            return "Hot and clear — stay hydrated."
        } else if lower.contains("clear") || lower.contains("mostly clear") {
            return "Clear skies — great day for outdoor activities."
        } else if lower.contains("cloud") || lower.contains("overcast") {
            return "Overcast but dry — good for errands."
        } else if lower.contains("fog") || lower.contains("haze") {
            return "Low visibility — drive carefully."
        } else if temp < 40 {
            return "Bundle up — it's cold out there."
        }
        return "Check conditions before heading out."
    }
}
