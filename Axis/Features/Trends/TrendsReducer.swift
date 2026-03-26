import ComposableArchitecture
import Foundation
import UIKit

struct AxisTrendClient {
    var computeTrends: @Sendable (Int) -> TrendService.TrendData
}

private enum AxisTrendKey: DependencyKey {
    static let liveValue = AxisTrendClient(
        computeTrends: { windowDays in
            TrendService.shared.computeTrends(windowDays: windowDays)
        }
    )
}

extension DependencyValues {
    var axisTrends: AxisTrendClient {
        get { self[AxisTrendKey.self] }
        set { self[AxisTrendKey.self] = newValue }
    }
}

@Reducer
struct TrendsReducer {
    @ObservableState
    struct State: Equatable {
        var selectedWindow: WindowSize = .week
        var isLoading: Bool = false
        var trendData: TrendDataState?

        // News feed
        var newsArticles: [NewsArticle] = []
        var isLoadingNews: Bool = false
        var selectedNewsCategory: NewsCategory = .higherEd
        var newsPage: Int = 0
        var articlesPerPage: Int = 10

        enum NewsCategory: String, CaseIterable, Equatable {
            case higherEd = "Higher Ed"
            case ai = "AI & Tech"
            case hbcu = "HBCU"
            case athletics = "Athletics"
            case leadership = "Leadership"
            case policy = "Policy"
            case data = "Data & Analytics"
            case hbcuSports = "HBCU Sports"
        }

        struct NewsArticle: Equatable, Identifiable {
            let id = UUID()
            var title: String
            var source: String
            var url: String
            var publishedDate: String
            var category: String
        }

        enum WindowSize: String, CaseIterable, Identifiable {
            case week = "7D"
            case twoWeeks = "14D"
            case month = "30D"
            case quarter = "90D"

            var id: String { rawValue }
            var days: Int {
                switch self {
                case .week: return 7
                case .twoWeeks: return 14
                case .month: return 30
                case .quarter: return 90
                }
            }
        }

        struct TrendDataState: Equatable {
            // Current period metrics
            var focusMinutes: Int = 0
            var focusSessions: Int = 0
            var pomodorosCompleted: Int = 0
            var prioritiesCompleted: Int = 0
            var prioritiesCreated: Int = 0
            var interactionsLogged: Int = 0
            var uniqueContactsReached: Int = 0
            var placesVisited: Int = 0
            var dadWinsCount: Int = 0

            // Previous period metrics (for comparisons)
            var prevFocusMinutes: Int = 0
            var prevPrioritiesCompleted: Int = 0
            var prevInteractionsLogged: Int = 0
            var prevDadWinsCount: Int = 0

            // Chart data
            var dailyFocusMinutes: [Double] = []
            var dailyInteractions: [Double] = []
            var dailyPrioritiesCompleted: [Double] = []

            // Insights
            var insights: [InsightState] = []

            struct InsightState: Equatable, Identifiable {
                let id: UUID
                var icon: String
                var message: String
                var category: String
            }

            var completionRate: Double {
                guard prioritiesCreated > 0 else { return 0 }
                return Double(prioritiesCompleted) / Double(prioritiesCreated)
            }

            var focusHours: String {
                let hours = focusMinutes / 60
                let mins = focusMinutes % 60
                if hours > 0 { return "\(hours)h \(mins)m" }
                return "\(mins)m"
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case windowChanged(State.WindowSize)
        case trendsLoaded(State.TrendDataState)
        case loadNews
        case refreshNews
        case newsLoaded([State.NewsArticle])
        case newsCategoryChanged(State.NewsCategory)
        case openArticle(String)
        case nextNewsPage
        case previousNewsPage
    }

    @Dependency(\.axisTrends) var trendClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                let window = state.selectedWindow.days
                return .run { send in
                    let data = trendClient.computeTrends(window)
                    let mapped = mapToState(data)
                    await send(.trendsLoaded(mapped))
                }

            case let .windowChanged(newWindow):
                state.selectedWindow = newWindow
                state.isLoading = true
                let window = newWindow.days
                return .run { send in
                    let data = trendClient.computeTrends(window)
                    let mapped = mapToState(data)
                    await send(.trendsLoaded(mapped))
                }

            case let .trendsLoaded(data):
                state.isLoading = false
                state.trendData = data
                return .none

            case .loadNews:
                state.isLoadingNews = true
                let category = state.selectedNewsCategory
                return .run { send in
                    let articles = await Self.fetchNews(category: category)
                    await send(.newsLoaded(articles))
                }

            case .refreshNews:
                state.newsArticles = []
                state.newsPage = 0
                return .send(.loadNews)

            case let .newsLoaded(articles):
                state.newsArticles = articles
                state.isLoadingNews = false
                return .none

            case let .newsCategoryChanged(cat):
                state.selectedNewsCategory = cat
                state.newsPage = 0
                return .send(.loadNews)

            case .nextNewsPage:
                let maxPage = max(0, (state.newsArticles.count - 1) / state.articlesPerPage)
                if state.newsPage < maxPage { state.newsPage += 1 }
                return .none

            case .previousNewsPage:
                if state.newsPage > 0 { state.newsPage -= 1 }
                return .none

            case let .openArticle(urlString):
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
                return .none
            }
        }
    }

    // MARK: - RSS Helpers

    private static func fetchNews(category: State.NewsCategory) async -> [State.NewsArticle] {
        let feeds: [(url: String, source: String)] = {
            switch category {
            case .higherEd:
                return [
                    ("https://www.insidehighered.com/rss/news", "Inside Higher Ed"),
                    ("https://hechingerreport.org/feed/", "Hechinger Report"),
                    ("https://www.edsurge.com/feeds/articles", "EdSurge"),
                    ("https://diverseeducation.com/feed/", "Diverse Education"),
                ]
            case .ai:
                return [
                    ("https://arstechnica.com/tag/artificial-intelligence/feed/", "Ars Technica"),
                    ("https://www.theverge.com/rss/ai-artificial-intelligence/index.xml", "The Verge"),
                    ("https://techcrunch.com/category/artificial-intelligence/feed/", "TechCrunch"),
                    ("https://feeds.feedburner.com/venturebeat/SZYF", "VentureBeat"),
                ]
            case .hbcu:
                return [
                    ("https://hbcudigest.com/feed/", "HBCU Digest"),
                    ("https://thehbcufoundation.org/feed/", "HBCU Foundation"),
                    ("https://hbcugameday.com/feed/", "HBCU Gameday"),
                ]
            case .athletics:
                return [
                    ("https://worldathletics.org/rss/news", "World Athletics"),
                    ("https://www.nbcolympics.com/rss", "NBC Olympics"),
                    ("https://www.flotrack.org/articles.rss", "FloTrack"),
                    ("https://www.letsrun.com/feed", "LetsRun"),
                ]
            case .leadership:
                return [
                    ("https://feeds.hbr.org/harvardbusiness", "Harvard Business Review"),
                    ("https://www.fastcompany.com/section/leadership/rss", "Fast Company"),
                    ("https://www.forbes.com/leadership/feed/", "Forbes Leadership"),
                ]
            case .policy:
                return [
                    ("https://www.ed.gov/feed", "US Dept of Education"),
                    ("https://www.highereddive.com/feeds/news/", "Higher Ed Dive"),
                    ("https://www.nacubo.org/rss/news", "NACUBO"),
                ]
            case .data:
                return [
                    ("https://towardsdatascience.com/feed", "Towards Data Science"),
                    ("https://feeds.feedburner.com/kdnuggets-data-mining-analytics", "KDnuggets"),
                    ("https://www.analyticsvidhya.com/feed/", "Analytics Vidhya"),
                ]
            case .hbcuSports:
                return [
                    ("https://hbcugameday.com/feed/", "HBCU Gameday"),
                    ("https://theswacnews.com/feed/", "SWAC News"),
                    ("https://hbcusports.com/feed/", "HBCU Sports"),
                ]
            }
        }()

        // Fetch all feeds in parallel
        let articles: [State.NewsArticle] = await withTaskGroup(of: [State.NewsArticle].self) { group in
            for feed in feeds {
                group.addTask {
                    await Self.fetchSingleFeed(urlString: feed.url, source: feed.source, category: category.rawValue)
                }
            }
            var all: [State.NewsArticle] = []
            for await batch in group { all.append(contentsOf: batch) }
            return all.sorted { $0.publishedDate > $1.publishedDate }
        }
        return articles
    }

    private static func fetchSingleFeed(urlString: String, source: String, category: String) async -> [State.NewsArticle] {
        guard let url = URL(string: urlString) else { return [] }
        var articles: [State.NewsArticle] = []
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let xml = String(data: data, encoding: .utf8) else { return [] }
            let items = xml.components(separatedBy: "<item>").dropFirst()
            for item in items.prefix(8) {
                var title = extractTag("title", from: item)
                let link = extractTag("link", from: item)
                let pubDate = extractTag("pubDate", from: item)
                title = cleanHTML(title)
                guard !title.isEmpty, title.count > 5 else { continue }
                articles.append(State.NewsArticle(
                    title: title,
                    source: source,
                    url: link.trimmingCharacters(in: .whitespacesAndNewlines),
                    publishedDate: formatPubDate(pubDate),
                    category: category
                ))
            }
        } catch { return [] }
        return articles
    }

    private static func extractTag(_ tag: String, from xml: String) -> String {
        // Try CDATA format first
        let cdataPattern = "<\(tag)><![CDATA["
        if let cdataStart = xml.range(of: cdataPattern),
           let cdataEnd = xml.range(of: "]]></\(tag)>", range: cdataStart.upperBound..<xml.endIndex) {
            return String(xml[cdataStart.upperBound..<cdataEnd.lowerBound])
        }
        // Standard format
        guard let startRange = xml.range(of: "<\(tag)>"),
              let endRange = xml.range(of: "</\(tag)>", range: startRange.upperBound..<xml.endIndex) else { return "" }
        return String(xml[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanHTML(_ text: String) -> String {
        var clean = text
        // Remove CDATA wrappers
        clean = clean.replacingOccurrences(of: "<![CDATA[", with: "")
        clean = clean.replacingOccurrences(of: "]]>", with: "")
        // HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
            ("&#8217;", "'"), ("&#8216;", "'"), ("&#8220;", "\""), ("&#8221;", "\""),
            ("&#8211;", "–"), ("&#8212;", "—"), ("&#038;", "&"), ("&apos;", "'"),
            ("&#39;", "'"), ("&nbsp;", " "), ("&#8230;", "…"), ("&ldquo;", "\""),
            ("&rdquo;", "\""), ("&lsquo;", "'"), ("&rsquo;", "'"), ("&ndash;", "–"),
            ("&mdash;", "—"), ("&hellip;", "…"),
        ]
        for (entity, replacement) in entities {
            clean = clean.replacingOccurrences(of: entity, with: replacement)
        }
        // Remove remaining HTML tags
        clean = clean.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatPubDate(_ dateStr: String) -> String {
        let trimmed = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try RFC 822 format (common in RSS)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                let relative = DateFormatter()
                relative.dateStyle = .medium
                relative.timeStyle = .none
                return relative.string(from: date)
            }
        }
        // Fallback: first 16 chars
        return String(trimmed.prefix(16))
    }
}

private func mapToState(_ data: TrendService.TrendData) -> TrendsReducer.State.TrendDataState {
    TrendsReducer.State.TrendDataState(
        focusMinutes: data.current.focusMinutes,
        focusSessions: data.current.focusSessions,
        pomodorosCompleted: data.current.pomodorosCompleted,
        prioritiesCompleted: data.current.prioritiesCompleted,
        prioritiesCreated: data.current.prioritiesCreated,
        interactionsLogged: data.current.interactionsLogged,
        uniqueContactsReached: data.current.uniqueContactsReached,
        placesVisited: data.current.placesVisited,
        dadWinsCount: data.current.dadWinsCount,
        prevFocusMinutes: data.previous.focusMinutes,
        prevPrioritiesCompleted: data.previous.prioritiesCompleted,
        prevInteractionsLogged: data.previous.interactionsLogged,
        prevDadWinsCount: data.previous.dadWinsCount,
        dailyFocusMinutes: data.dailyFocusMinutes,
        dailyInteractions: data.dailyInteractions,
        dailyPrioritiesCompleted: data.dailyPrioritiesCompleted,
        insights: data.insights.map {
            .init(id: $0.id, icon: $0.icon, message: $0.message, category: $0.category)
        }
    )
}
