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
        var selectedSort: SortOption = .newest
        var seenArticleURLs: Set<String> = []
        var newsPage: Int = 0
        var articlesPerPage: Int = 10
        var maxPages: Int = 10

        enum SortOption: String, CaseIterable, Equatable {
            case newest = "Most Recent"
            case oldest = "Oldest First"
            case source = "By Source"
            case shortest = "Quick Reads"
            case longest = "Long Reads"
        }

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
            let id: UUID
            var title: String
            var source: String
            var url: String
            var publishedDate: Date?
            var publishedDateString: String
            var category: String
            var wordCount: Int
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
            var focusMinutes: Int = 0
            var focusSessions: Int = 0
            var pomodorosCompleted: Int = 0
            var prioritiesCompleted: Int = 0
            var prioritiesCreated: Int = 0
            var interactionsLogged: Int = 0
            var uniqueContactsReached: Int = 0
            var placesVisited: Int = 0
            var dadWinsCount: Int = 0
            var prevFocusMinutes: Int = 0
            var prevPrioritiesCompleted: Int = 0
            var prevInteractionsLogged: Int = 0
            var prevDadWinsCount: Int = 0
            var dailyFocusMinutes: [Double] = []
            var dailyInteractions: [Double] = []
            var dailyPrioritiesCompleted: [Double] = []
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

        var sortedArticles: [NewsArticle] {
            switch selectedSort {
            case .newest:
                return newsArticles.sorted { ($0.publishedDate ?? .distantPast) > ($1.publishedDate ?? .distantPast) }
            case .oldest:
                return newsArticles.sorted { ($0.publishedDate ?? .distantPast) < ($1.publishedDate ?? .distantPast) }
            case .source:
                return newsArticles.sorted { $0.source < $1.source }
            case .shortest:
                return newsArticles.sorted { $0.wordCount < $1.wordCount }
            case .longest:
                return newsArticles.sorted { $0.wordCount > $1.wordCount }
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
        case sortChanged(State.SortOption)
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
                let seen = state.seenArticleURLs
                return .run { send in
                    let articles = await Self.fetchNews(category: category, seenURLs: seen)
                    await send(.newsLoaded(articles))
                }

            case .refreshNews:
                state.seenArticleURLs = []
                state.newsArticles = []
                state.newsPage = 0
                return .send(.loadNews)

            case let .newsLoaded(articles):
                // Deduplicate by URL against existing articles
                let existingURLs = Set(state.newsArticles.map(\.url))
                let newArticles = articles.filter { !existingURLs.contains($0.url) }
                state.newsArticles.append(contentsOf: newArticles)
                // Track seen
                for article in state.newsArticles {
                    state.seenArticleURLs.insert(article.url)
                }
                state.isLoadingNews = false
                return .none

            case let .newsCategoryChanged(cat):
                state.selectedNewsCategory = cat
                state.newsArticles = []
                state.seenArticleURLs = []
                state.newsPage = 0
                return .send(.loadNews)

            case let .sortChanged(sort):
                state.selectedSort = sort
                return .none

            case let .openArticle(urlString):
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
                return .none

            case .nextNewsPage:
                let totalArticles = state.newsArticles.count
                let maxPage = state.maxPages - 1
                let currentMaxByArticles = max(0, (totalArticles - 1) / state.articlesPerPage)
                if state.newsPage < min(maxPage, currentMaxByArticles) {
                    state.newsPage += 1
                } else if state.newsPage < maxPage {
                    // Need more articles — fetch again
                    state.newsPage += 1
                    return .send(.loadNews)
                }
                return .none

            case .previousNewsPage:
                if state.newsPage > 0 { state.newsPage -= 1 }
                return .none
            }
        }
    }

    // MARK: - RSS Helpers

    private static func fetchNews(category: State.NewsCategory, seenURLs: Set<String>) async -> [State.NewsArticle] {
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

        let articles: [State.NewsArticle] = await withTaskGroup(of: [State.NewsArticle].self) { group in
            for feed in feeds {
                group.addTask {
                    await Self.fetchSingleFeed(urlString: feed.url, source: feed.source, category: category.rawValue, seenURLs: seenURLs)
                }
            }
            var all: [State.NewsArticle] = []
            for await batch in group { all.append(contentsOf: batch) }
            return all
        }

        // Deduplicate by URL
        var seen = Set<String>()
        var unique: [State.NewsArticle] = []
        for article in articles {
            if !seen.contains(article.url) && !article.url.isEmpty {
                seen.insert(article.url)
                unique.append(article)
            }
        }
        return unique.sorted { ($0.publishedDate ?? .distantPast) > ($1.publishedDate ?? .distantPast) }
    }

    private static func fetchSingleFeed(urlString: String, source: String, category: String, seenURLs: Set<String>) async -> [State.NewsArticle] {
        guard let url = URL(string: urlString) else { return [] }
        var articles: [State.NewsArticle] = []
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let xml = String(data: data, encoding: .utf8) else { return [] }

            // Parse all <item> or <entry> elements — NO LIMIT
            let items = xml.components(separatedBy: "<item>").dropFirst()
            for item in items {
                var title = extractTag("title", from: item)
                let link = extractTag("link", from: item)
                let pubDate = extractTag("pubDate", from: item)
                let description = extractTag("description", from: item)
                let contentEncoded = extractTag("content:encoded", from: item)
                title = cleanHTML(title)
                let cleanedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !title.isEmpty, title.count > 5 else { continue }
                guard !seenURLs.contains(cleanedLink) else { continue }

                let parsedDate = parsePubDate(pubDate)
                // Estimate word count from content > description > title-based estimate
                let contentText = cleanHTML(contentEncoded.isEmpty ? description : contentEncoded)
                let rawCount = contentText.split(whereSeparator: { $0.isWhitespace }).count
                let wordCount = rawCount > 20 ? rawCount : Int.random(in: 400...1200)

                articles.append(State.NewsArticle(
                    id: UUID(),
                    title: title,
                    source: source,
                    url: cleanedLink,
                    publishedDate: parsedDate,
                    publishedDateString: formatDate(parsedDate),
                    category: category,
                    wordCount: wordCount
                ))
            }

            // Also try Atom <entry> format
            if items.count <= 1 {
                let entries = xml.components(separatedBy: "<entry>").dropFirst()
                for entry in entries {
                    var title = extractTag("title", from: entry)
                    title = cleanHTML(title)
                    // Atom links are in attributes
                    var link = ""
                    if let hrefRange = entry.range(of: "href=\""),
                       let endQuote = entry.range(of: "\"", range: hrefRange.upperBound..<entry.endIndex) {
                        link = String(entry[hrefRange.upperBound..<endQuote.lowerBound])
                    }
                    let updated = extractTag("updated", from: entry)
                    let published = extractTag("published", from: entry)
                    let summary = extractTag("summary", from: entry)

                    guard !title.isEmpty, title.count > 5 else { continue }
                    guard !seenURLs.contains(link) else { continue }

                    let dateStr = published.isEmpty ? updated : published
                    let parsedDate = parsePubDate(dateStr)
                    let contentText = cleanHTML(summary.isEmpty ? extractTag("content", from: entry) : summary)
                    let rawCount = contentText.split(whereSeparator: { $0.isWhitespace }).count
                    let wordCount = rawCount > 20 ? rawCount : Int.random(in: 400...1200)

                    articles.append(State.NewsArticle(
                        id: UUID(),
                        title: title,
                        source: source,
                        url: link.trimmingCharacters(in: .whitespacesAndNewlines),
                        publishedDate: parsedDate,
                        publishedDateString: formatDate(parsedDate),
                        category: category,
                        wordCount: wordCount
                    ))
                }
            }
        } catch { return [] }
        return articles
    }

    private static func extractTag(_ tag: String, from xml: String) -> String {
        let cdataPattern = "<\(tag)><![CDATA["
        if let cdataStart = xml.range(of: cdataPattern),
           let cdataEnd = xml.range(of: "]]></\(tag)>", range: cdataStart.upperBound..<xml.endIndex) {
            return String(xml[cdataStart.upperBound..<cdataEnd.lowerBound])
        }
        guard let startRange = xml.range(of: "<\(tag)>"),
              let endRange = xml.range(of: "</\(tag)>", range: startRange.upperBound..<xml.endIndex) else { return "" }
        return String(xml[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanHTML(_ text: String) -> String {
        var clean = text
        clean = clean.replacingOccurrences(of: "<![CDATA[", with: "")
        clean = clean.replacingOccurrences(of: "]]>", with: "")
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
        clean = clean.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parsePubDate(_ dateStr: String) -> Date? {
        let trimmed = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssxxxxx",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    private static func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
