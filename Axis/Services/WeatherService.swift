import CoreLocation
import Foundation

@Observable
final class WeatherService {
    static let shared = WeatherService()

    private(set) var currentWeather: WeatherData?
    private(set) var isLoading = false
    private(set) var lastErrorMessage: String?

    struct WeatherData: Equatable {
        let temperature: Double
        let condition: String
        let icon: String
        let humidity: Int
        let feelsLike: Double
        let location: String
        let actionableNote: String

        var temperatureFormatted: String {
            "\(Int(temperature))°"
        }

        var sfSymbol: String {
            switch icon {
            case "01d": return "sun.max.fill"
            case "01n": return "moon.fill"
            case "02d", "02n": return "cloud.sun.fill"
            case "03d", "03n", "04d", "04n": return "cloud.fill"
            case "09d", "09n": return "cloud.drizzle.fill"
            case "10d", "10n": return "cloud.rain.fill"
            case "11d", "11n": return "cloud.bolt.fill"
            case "13d", "13n": return "cloud.snow.fill"
            case "50d", "50n": return "cloud.fog.fill"
            default: return "cloud.fill"
            }
        }
    }

    private init() {}

    private func configuredAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["OPENWEATHERMAP_API_KEY"], !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "OPENWEATHERMAP_API_KEY") as? String, !plist.isEmpty {
            return plist
        }
        return nil
    }

    func fetchWeather(latitude: Double = 30.2672, longitude: Double = -97.7431) async {
        // Default to Austin, TX coordinates
        guard !isLoading else { return }

        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        // Read from env or Info.plist; fall back to demo weather when unavailable.
        guard let apiKey = configuredAPIKey() else {
            await MainActor.run {
                self.lastErrorMessage = "OpenWeatherMap API key is not configured."
                self.currentWeather = WeatherData(
                    temperature: 75,
                    condition: "Clear",
                    icon: "01d",
                    humidity: 45,
                    feelsLike: 73,
                    location: "Marshall, TX",
                    actionableNote: "Weather service in demo mode (missing API key)."
                )
            }
            return
        }
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=imperial"

        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)

            let weather = WeatherData(
                temperature: response.main.temp,
                condition: response.weather.first?.main ?? "Unknown",
                icon: response.weather.first?.icon ?? "01d",
                humidity: response.main.humidity,
                feelsLike: response.main.feelsLike,
                location: response.name,
                actionableNote: generateActionableNote(temp: response.main.temp, condition: response.weather.first?.main ?? "")
            )

            await MainActor.run {
                self.lastErrorMessage = nil
                self.currentWeather = weather
            }
        } catch {
            // Provide fallback data for demo/development
            await MainActor.run {
                self.lastErrorMessage = "Weather fetch failed: \(error.localizedDescription)"
                self.currentWeather = WeatherData(
                    temperature: 75,
                    condition: "Clear",
                    icon: "01d",
                    humidity: 45,
                    feelsLike: 73,
                    location: "Marshall, TX",
                    actionableNote: "Clear skies — great day for outdoor activities."
                )
            }
        }
    }

    private func generateActionableNote(temp: Double, condition: String) -> String {
        switch condition.lowercased() {
        case "rain", "drizzle":
            return "Rain expected — grab an umbrella for pickup."
        case "thunderstorm":
            return "Storms today — consider indoor plans."
        case "snow":
            return "Snow — allow extra drive time."
        case "clear" where temp > 90:
            return "Hot and clear — stay hydrated."
        case "clear":
            return "Clear skies — great day for outdoor activities."
        case "clouds":
            return "Overcast but dry — good for errands."
        default:
            return "Check conditions before heading out."
        }
    }
}

// MARK: - OpenWeatherMap Response Models
private struct OpenWeatherResponse: Decodable {
    let main: MainData
    let weather: [WeatherInfo]
    let name: String

    struct MainData: Decodable {
        let temp: Double
        let feelsLike: Double
        let humidity: Int

        enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
            case humidity
        }
    }

    struct WeatherInfo: Decodable {
        let main: String
        let icon: String
    }
}
