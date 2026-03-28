import CoreLocation
import Foundation
import WeatherKit

@Observable
final class WeatherService {
    static let shared = WeatherService()

    private(set) var currentWeather: WeatherData?
    private(set) var hourlyForecast: [HourlyWeather] = []
    private(set) var dailyForecast: [DailyWeather] = []
    private(set) var isLoading = false
    private(set) var lastErrorMessage: String?
    private(set) var lastUpdatedAt: Date?

    struct WeatherData: Equatable {
        let temperature: Double
        let condition: String
        let icon: String
        let humidity: Int
        let feelsLike: Double
        let location: String
        let actionableNote: String
        let windSpeed: Double
        let windDirection: String
        let uvIndex: Int
        let visibility: Double
        let pressure: Double
        let dewPoint: Double
        let cloudCover: Int
        let sunrise: Date?
        let sunset: Date?
        let highTemp: Double
        let lowTemp: Double

        var temperatureFormatted: String { "\(Int(temperature.rounded()))°" }
        var sfSymbol: String { icon }
    }

    struct HourlyWeather: Equatable, Identifiable {
        let id = UUID()
        let date: Date
        let temperature: Double
        let icon: String
        let precipChance: Int
        let condition: String

        var hourLabel: String {
            let f = DateFormatter()
            f.dateFormat = "ha"
            return f.string(from: date).lowercased()
        }
    }

    struct DailyWeather: Equatable, Identifiable {
        let id = UUID()
        let date: Date
        let highTemp: Double
        let lowTemp: Double
        let icon: String
        let condition: String
        let precipChance: Int

        var dayLabel: String {
            if Calendar.current.isDateInToday(date) { return "Today" }
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f.string(from: date)
        }
    }

    private let weatherService = WeatherKit.WeatherService.shared
    private init() {}

    func fetchWeather() async -> WeatherData? {
        let cachedWeather = await MainActor.run { currentWeather }
        let alreadyLoading = await MainActor.run { isLoading }
        if alreadyLoading { return cachedWeather }

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

        // Try WeatherKit first, fall back to Open-Meteo
        do {
            let data = try await fetchFromWeatherKit(location: location)
            await MainActor.run {
                self.lastErrorMessage = nil
                self.currentWeather = data
                self.lastUpdatedAt = Date()
            }
            return data
        } catch {
            // Fall back to Open-Meteo
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
    }

    // MARK: - WeatherKit (Apple's native data — matches iPhone Weather app)

    private func fetchFromWeatherKit(location: CLLocation) async throws -> WeatherData {
        let weather = try await weatherService.weather(for: location)
        let current = weather.currentWeather
        let daily = weather.dailyForecast
        let hourly = weather.hourlyForecast

        let locationName = await resolveLocationName(for: location)
        let todayForecast = daily.first

        // Build hourly forecast (next 24 hours)
        let now = Date()
        let hourlyItems = hourly.filter { $0.date >= now }.prefix(24).map { h in
            HourlyWeather(
                date: h.date,
                temperature: h.temperature.converted(to: .fahrenheit).value,
                icon: h.symbolName,
                precipChance: Int(h.precipitationChance * 100),
                condition: h.condition.description
            )
        }

        // Build daily forecast (10 days)
        let dailyItems = daily.prefix(10).map { d in
            DailyWeather(
                date: d.date,
                highTemp: d.highTemperature.converted(to: .fahrenheit).value,
                lowTemp: d.lowTemperature.converted(to: .fahrenheit).value,
                icon: d.symbolName,
                condition: d.condition.description,
                precipChance: Int(d.precipitationChance * 100)
            )
        }

        await MainActor.run {
            self.hourlyForecast = Array(hourlyItems)
            self.dailyForecast = Array(dailyItems)
        }

        let temp = current.temperature.converted(to: .fahrenheit).value
        let feelsLike = current.apparentTemperature.converted(to: .fahrenheit).value
        let dewPoint = current.dewPoint.converted(to: .fahrenheit).value
        let windSpeed = current.wind.speed.converted(to: .milesPerHour).value
        let visibility = current.visibility.converted(to: .miles).value
        let pressure = current.pressure.converted(to: .inchesOfMercury).value

        return WeatherData(
            temperature: temp,
            condition: current.condition.description,
            icon: current.symbolName,
            humidity: Int(current.humidity * 100),
            feelsLike: feelsLike,
            location: locationName,
            actionableNote: generateActionableNote(temp: temp, condition: current.condition.description),
            windSpeed: windSpeed,
            windDirection: compassDirection(current.wind.direction.value),
            uvIndex: current.uvIndex.value,
            visibility: visibility,
            pressure: pressure,
            dewPoint: dewPoint,
            cloudCover: Int(current.cloudCover * 100),
            sunrise: todayForecast?.sun.sunrise,
            sunset: todayForecast?.sun.sunset,
            highTemp: todayForecast?.highTemperature.converted(to: .fahrenheit).value ?? temp,
            lowTemp: todayForecast?.lowTemperature.converted(to: .fahrenheit).value ?? temp
        )
    }

    // MARK: - Open-Meteo Fallback

    private func fetchFromOpenMeteo(location: CLLocation) async throws -> WeatherData {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "wind_speed_unit", value: "mph"),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let current = json["current"] as! [String: Any]
        let daily = json["daily"] as? [String: Any]

        let temp = (current["temperature_2m"] as? Double) ?? 0
        let feelsLike = (current["apparent_temperature"] as? Double) ?? temp
        let humidity = (current["relative_humidity_2m"] as? Int) ?? 0
        let weatherCode = (current["weather_code"] as? Int) ?? 0
        let isDay = (current["is_day"] as? Int) ?? 1
        let windSpeed = (current["wind_speed_10m"] as? Double) ?? 0
        let windDir = (current["wind_direction_10m"] as? Double) ?? 0

        let highTemps = (daily?["temperature_2m_max"] as? [Double]) ?? []
        let lowTemps = (daily?["temperature_2m_min"] as? [Double]) ?? []

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
            actionableNote: generateActionableNote(temp: temp, condition: conditionText),
            windSpeed: windSpeed,
            windDirection: compassDirection(windDir),
            uvIndex: 0,
            visibility: 0,
            pressure: 0,
            dewPoint: 0,
            cloudCover: 0,
            sunrise: nil,
            sunset: nil,
            highTemp: highTemps.first ?? temp,
            lowTemp: lowTemps.first ?? temp
        )
    }

    // MARK: - Helpers

    private func compassDirection(_ degrees: Double) -> String {
        let dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let idx = Int((degrees + 11.25) / 22.5) % 16
        return dirs[idx]
    }

    private static func conditionText(for code: Int) -> String {
        switch code {
        case 0: return "Clear"; case 1: return "Mostly Clear"; case 2: return "Partly Cloudy"; case 3: return "Overcast"
        case 45, 48: return "Foggy"; case 51, 53, 55: return "Drizzle"; case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"; case 66, 67: return "Freezing Rain"; case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"; case 80, 81, 82: return "Rain Showers"; case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"; case 96, 99: return "Thunderstorm with Hail"
        default: return "Unknown"
        }
    }

    private static func sfSymbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1: return isDay ? "sun.min.fill" : "moon.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57, 66, 67: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    // MARK: - Location

    private func resolveLocation() async -> CLLocation? {
        let locationService = await MainActor.run { LocationService.shared }
        if let existing = await MainActor.run(body: { locationService.effectiveLocation }) { return existing }
        if let cached = await MainActor.run(body: { locationService.currentLocation }) { return cached }

        let status = await MainActor.run { locationService.authorizationStatus }
        if status == .denied || status == .restricted { return nil }

        await MainActor.run {
            if status == .notDetermined { locationService.requestPermission() }
            else { locationService.requestLocation() }
        }

        for _ in 0..<20 {
            let currentStatus = await MainActor.run { locationService.authorizationStatus }
            if currentStatus == .denied || currentStatus == .restricted { return nil }
            if let loc = await MainActor.run(body: { locationService.effectiveLocation ?? locationService.currentLocation }) { return loc }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return nil
    }

    private func resolveLocationName(for location: CLLocation) async -> String {
        let customName = await MainActor.run { LocationService.shared.currentLocationName }
        if !customName.isEmpty { return customName }
        return await reverseGeocode(location)
    }

    private func reverseGeocode(_ location: CLLocation) async -> String {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let p = placemarks.first {
                return [p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            }
        } catch { }
        return "Current Location"
    }

    private func generateActionableNote(temp: Double, condition: String) -> String {
        let lower = condition.lowercased()
        if lower.contains("rain") || lower.contains("drizzle") { return "Rain expected — grab an umbrella." }
        if lower.contains("thunderstorm") { return "Storms today — consider indoor plans." }
        if lower.contains("snow") { return "Snow — allow extra drive time." }
        if lower.contains("clear") && temp > 90 { return "Hot and clear — stay hydrated." }
        if lower.contains("clear") || lower.contains("mostly clear") { return "Clear skies — great day for outdoor activities." }
        if lower.contains("cloud") || lower.contains("overcast") { return "Overcast but dry — good for errands." }
        if lower.contains("fog") { return "Low visibility — drive carefully." }
        if temp < 40 { return "Bundle up — it's cold out there." }
        return "Check conditions before heading out."
    }
}
