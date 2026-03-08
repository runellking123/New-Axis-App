import CoreLocation
import Foundation
import WeatherKit

@Observable
final class WeatherService {
    static let shared = WeatherService()

    private(set) var currentWeather: WeatherData?
    private(set) var isLoading = false
    private(set) var lastErrorMessage: String?

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

    func fetchWeather() async {
        guard !isLoading else { return }

        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        let locationService = LocationService.shared
        locationService.requestLocation()

        // Wait briefly for location
        for _ in 0..<10 {
            if locationService.currentLocation != nil { break }
            try? await Task.sleep(for: .milliseconds(300))
        }

        guard let location = locationService.currentLocation else {
            await MainActor.run {
                self.lastErrorMessage = "Location unavailable"
                self.currentWeather = WeatherData(
                    temperature: 75,
                    condition: "Unknown",
                    icon: "cloud.fill",
                    humidity: 50,
                    feelsLike: 75,
                    location: "Location unavailable",
                    actionableNote: "Enable location access for real weather data."
                )
            }
            return
        }

        do {
            let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
            let current = weather.currentWeather

            let tempF = current.temperature.converted(to: .fahrenheit).value
            let feelsLikeF = current.apparentTemperature.converted(to: .fahrenheit).value
            let conditionText = current.condition.description
            let symbol = current.symbolName
            let humidity = Int(current.humidity * 100)

            // Reverse geocode for location name
            let locationName = await reverseGeocode(location)

            let data = WeatherData(
                temperature: tempF,
                condition: conditionText,
                icon: symbol,
                humidity: humidity,
                feelsLike: feelsLikeF,
                location: locationName,
                actionableNote: generateActionableNote(temp: tempF, condition: conditionText)
            )

            await MainActor.run {
                self.lastErrorMessage = nil
                self.currentWeather = data
            }
        } catch {
            await MainActor.run {
                self.lastErrorMessage = "Weather fetch failed: \(error.localizedDescription)"
                self.currentWeather = WeatherData(
                    temperature: 75,
                    condition: "Clear",
                    icon: "sun.max.fill",
                    humidity: 45,
                    feelsLike: 73,
                    location: "Weather unavailable",
                    actionableNote: "Weather data temporarily unavailable."
                )
            }
        }
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
