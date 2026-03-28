import SwiftUI

struct WeatherDetailView: View {
    let weather: WeatherService.WeatherData
    let hourly: [WeatherService.HourlyWeather]
    let daily: [WeatherService.DailyWeather]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero section
                    heroSection
                        .padding(.bottom, 20)

                    // Hourly forecast
                    if !hourly.isEmpty {
                        hourlySection
                            .padding(.bottom, 16)
                    }

                    // 10-day forecast
                    if !daily.isEmpty {
                        dailySection
                            .padding(.bottom, 16)
                    }

                    // Weather details grid
                    detailsGrid
                        .padding(.bottom, 16)

                    // Sunrise/Sunset
                    if weather.sunrise != nil || weather.sunset != nil {
                        sunSection
                            .padding(.bottom, 16)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(weatherGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Background Gradient

    private var weatherGradient: LinearGradient {
        let condition = weather.condition.lowercased()
        let colors: [Color]
        if condition.contains("clear") || condition.contains("sunny") {
            colors = [Color(red: 0.15, green: 0.5, blue: 0.85), Color(red: 0.35, green: 0.7, blue: 0.95)]
        } else if condition.contains("cloud") || condition.contains("overcast") {
            colors = [Color(red: 0.4, green: 0.45, blue: 0.55), Color(red: 0.55, green: 0.6, blue: 0.7)]
        } else if condition.contains("rain") || condition.contains("drizzle") {
            colors = [Color(red: 0.25, green: 0.3, blue: 0.4), Color(red: 0.35, green: 0.4, blue: 0.5)]
        } else if condition.contains("snow") {
            colors = [Color(red: 0.6, green: 0.65, blue: 0.75), Color(red: 0.75, green: 0.8, blue: 0.88)]
        } else if condition.contains("thunder") {
            colors = [Color(red: 0.15, green: 0.15, blue: 0.25), Color(red: 0.25, green: 0.25, blue: 0.35)]
        } else {
            colors = [Color(red: 0.2, green: 0.45, blue: 0.75), Color(red: 0.4, green: 0.65, blue: 0.85)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 4) {
            Text(weather.location)
                .font(.title2)
                .foregroundStyle(.white)

            Text("\(Int(weather.temperature.rounded()))°")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(.white)

            Text(weather.condition)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))

            Text("H:\(Int(weather.highTemp.rounded()))° L:\(Int(weather.lowTemp.rounded()))°")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 20)
    }

    // MARK: - Hourly

    private var hourlySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(weather.actionableNote)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 4)

            Divider().background(.white.opacity(0.3))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(hourly.prefix(24)) { hour in
                        VStack(spacing: 8) {
                            Text(hour.hourLabel)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))

                            Image(systemName: hour.icon)
                                .symbolRenderingMode(.multicolor)
                                .font(.title3)

                            if hour.precipChance > 0 {
                                Text("\(hour.precipChance)%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.cyan)
                            }

                            Text("\(Int(hour.temperature.rounded()))°")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Daily

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.white.opacity(0.6))
                Text("10-DAY FORECAST")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1)
            }

            Divider().background(.white.opacity(0.3))

            let globalLow = daily.map(\.lowTemp).min() ?? 0
            let globalHigh = daily.map(\.highTemp).max() ?? 100

            ForEach(daily) { day in
                HStack(spacing: 10) {
                    Text(day.dayLabel)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(width: 44, alignment: .leading)

                    Image(systemName: day.icon)
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 24)

                    if day.precipChance > 0 {
                        Text("\(day.precipChance)%")
                            .font(.system(size: 10))
                            .foregroundStyle(.cyan)
                            .frame(width: 28)
                    } else {
                        Color.clear.frame(width: 28)
                    }

                    Text("\(Int(day.lowTemp.rounded()))°")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 28)

                    // Temperature bar
                    GeometryReader { geo in
                        let range = globalHigh - globalLow
                        let barStart = range > 0 ? (day.lowTemp - globalLow) / range : 0
                        let barEnd = range > 0 ? (day.highTemp - globalLow) / range : 1

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.15))
                                .frame(height: 4)

                            Capsule()
                                .fill(tempGradient)
                                .frame(width: max(8, geo.size.width * (barEnd - barStart)), height: 4)
                                .offset(x: geo.size.width * barStart)
                        }
                    }
                    .frame(height: 4)

                    Text("\(Int(day.highTemp.rounded()))°")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 28)
                }
                .padding(.vertical, 4)

                if day.id != daily.last?.id {
                    Divider().background(.white.opacity(0.15))
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var tempGradient: LinearGradient {
        LinearGradient(colors: [.blue, .green, .yellow, .orange], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Details Grid

    private var detailsGrid: some View {
        detailsGridContent
    }

    @ViewBuilder
    private var detailsGridContent: some View {
        let items: [(icon: String, title: String, value: String, subtitle: String)] = [
            ("thermometer.medium", "FEELS LIKE", "\(Int(weather.feelsLike.rounded()))°", ""),
            ("humidity.fill", "HUMIDITY", "\(weather.humidity)%", "Dew point: \(Int(weather.dewPoint.rounded()))°"),
            ("wind", "WIND", "\(Int(weather.windSpeed.rounded())) mph", weather.windDirection),
            ("sun.max.fill", "UV INDEX", "\(weather.uvIndex)", weather.uvIndex <= 2 ? "Low" : weather.uvIndex <= 5 ? "Moderate" : weather.uvIndex <= 7 ? "High" : "Very High"),
            ("eye.fill", "VISIBILITY", weather.visibility > 0 ? "\(Int(weather.visibility.rounded())) mi" : "--", ""),
            ("gauge.medium", "PRESSURE", weather.pressure > 0 ? String(format: "%.2f in", weather.pressure) : "--", ""),
        ]

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(0..<items.count, id: \.self) { i in
                let item = items[i]
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(item.title)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(0.5)
                    }
                    Text(item.value)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.ultraThinMaterial.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Sunrise/Sunset

    private var sunSection: some View {
        HStack(spacing: 16) {
            if let sunrise = weather.sunrise {
                sunTimeCard(icon: "sunrise.fill", label: "SUNRISE", time: sunrise)
            }
            if let sunset = weather.sunset {
                sunTimeCard(icon: "sunset.fill", label: "SUNSET", time: sunset)
            }
        }
    }

    private func sunTimeCard(icon: String, label: String, time: Date) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(0.5)
            }
            Text(time, style: .time)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
