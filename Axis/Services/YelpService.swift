import Foundation

@Observable
final class YelpService {
    static let shared = YelpService()

    private let apiKey = "P8gTdbKvLFB7SeiXUSi4i9Wv75FuyYoUFk_uog4kZ2WkRSa7IkCiif3eiB435g8y2opb-LE_wB4sRI7Acd4-NeCWPdicU7SBm4rlz3npbBDlgjNeLHQfjHuejbrEaXYx"
    private let baseURL = "https://api.yelp.com/v3"

    struct YelpBusiness: Sendable {
        let name: String
        let rating: Double
        let reviewCount: Int
        let phone: String
        let address: String
        let categories: [String]
        let imageURL: String
        let yelpURL: String
        let isClosed: Bool
        let hours: [DayHours]
        let price: String
        let distance: Double // meters

        struct DayHours: Sendable {
            let day: Int // 0=Mon, 6=Sun
            let start: String // "1100"
            let end: String // "2200"
            let isOvernight: Bool
        }

        var formattedRating: String {
            String(format: "%.1f", rating)
        }

        var starsCount: Int {
            Int(rating.rounded())
        }

        var todayHours: String {
            let weekday = (Calendar.current.component(.weekday, from: Date()) + 5) % 7 // Convert to 0=Mon
            guard let today = hours.first(where: { $0.day == weekday }) else { return "Hours N/A" }
            return "\(formatTime(today.start)) – \(formatTime(today.end))"
        }

        var isOpenNow: Bool {
            !isClosed
        }

        private func formatTime(_ time: String) -> String {
            guard time.count == 4,
                  let hour = Int(time.prefix(2)),
                  let min = Int(time.suffix(2)) else { return time }
            let h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
            let ampm = hour >= 12 ? "PM" : "AM"
            return min == 0 ? "\(h) \(ampm)" : "\(h):\(String(format: "%02d", min)) \(ampm)"
        }
    }

    func searchBusinesses(term: String, location: String, limit: Int = 10) async -> [YelpBusiness] {
        var components = URLComponents(string: "\(baseURL)/businesses/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "location", value: location),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sort_by", value: "best_match")
        ]
        return await fetch(url: components.url!)
    }

    func searchBusinesses(term: String, latitude: Double, longitude: Double, limit: Int = 10) async -> [YelpBusiness] {
        var components = URLComponents(string: "\(baseURL)/businesses/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sort_by", value: "best_match")
        ]
        return await fetch(url: components.url!)
    }

    func searchEvents(location: String) async -> [YelpBusiness] {
        var allResults: [YelpBusiness] = []
        let queries = ["live music", "comedy club", "theater", "nightclub", "concert venue", "sports bar"]
        for query in queries {
            let results = await searchBusinesses(term: query, location: location, limit: 3)
            allResults.append(contentsOf: results)
            if allResults.count >= 12 { break }
        }
        return allResults
    }

    func searchByCategory(categories: String, location: String, limit: Int = 10) async -> [YelpBusiness] {
        var components = URLComponents(string: "\(baseURL)/businesses/search")!
        components.queryItems = [
            URLQueryItem(name: "categories", value: categories),
            URLQueryItem(name: "location", value: location),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sort_by", value: "rating")
        ]
        return await fetch(url: components.url!)
    }

    private func fetch(url: URL) async -> [YelpBusiness] {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let businesses = json["businesses"] as? [[String: Any]] else { return [] }

            return businesses.compactMap { biz -> YelpBusiness? in
                guard let name = biz["name"] as? String else { return nil }
                let rating = biz["rating"] as? Double ?? 0
                let reviewCount = biz["review_count"] as? Int ?? 0
                let phone = biz["display_phone"] as? String ?? ""
                let isClosed = biz["is_closed"] as? Bool ?? false
                let price = biz["price"] as? String ?? ""
                let distance = biz["distance"] as? Double ?? 0
                let imageURL = biz["image_url"] as? String ?? ""
                let yelpURL = biz["url"] as? String ?? ""

                let location = biz["location"] as? [String: Any]
                let displayAddress = location?["display_address"] as? [String] ?? []
                let address = displayAddress.joined(separator: ", ")

                let cats = biz["categories"] as? [[String: Any]] ?? []
                let categories = cats.compactMap { $0["title"] as? String }

                // Parse hours
                var dayHours: [YelpBusiness.DayHours] = []
                if let bizHours = biz["business_hours"] as? [[String: Any]],
                   let firstSchedule = bizHours.first,
                   let open = firstSchedule["open"] as? [[String: Any]] {
                    for slot in open {
                        if let day = slot["day"] as? Int,
                           let start = slot["start"] as? String,
                           let end = slot["end"] as? String {
                            let overnight = slot["is_overnight"] as? Bool ?? false
                            dayHours.append(YelpBusiness.DayHours(day: day, start: start, end: end, isOvernight: overnight))
                        }
                    }
                }

                return YelpBusiness(
                    name: name, rating: rating, reviewCount: reviewCount,
                    phone: phone, address: address, categories: categories,
                    imageURL: imageURL, yelpURL: yelpURL, isClosed: isClosed,
                    hours: dayHours, price: price, distance: distance
                )
            }
        } catch {
            return []
        }
    }
}
