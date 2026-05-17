import ComposableArchitecture
import SwiftUI

struct TrendsView: View {
    @Bindable var store: StoreOf<TrendsReducer>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    newsCategoryPicker
                    sortFilterBar
                    newsContent
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("News")
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(Color.axisGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { store.send(.refreshNews) } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.axisGold)
                    }
                    .disabled(store.isLoadingNews)
                }
            }
            .onAppear {
                if store.newsArticles.isEmpty {
                    store.send(.loadNews)
                }
            }
        }
    }

    // MARK: - Category Picker

    private var newsCategoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrendsReducer.State.NewsCategory.allCases, id: \.self) { category in
                    Button { store.send(.newsCategoryChanged(category)) } label: {
                        Text(category.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(store.selectedNewsCategory == category ? Color.axisGold : Color(.systemGray5))
                            .foregroundStyle(store.selectedNewsCategory == category ? .white : .secondary)
                            .clipShape(.capsule)
                    }
                }
            }
        }
    }

    // MARK: - Sort / Filter Bar

    private var sortFilterBar: some View {
        HStack {
            Text("\(store.newsArticles.count) articles")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Menu {
                ForEach(TrendsReducer.State.SortOption.allCases, id: \.self) { option in
                    Button {
                        store.send(.sortChanged(option))
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if store.selectedSort == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text(store.selectedSort.rawValue)
                        .font(.caption)
                }
                .foregroundStyle(Color.axisGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.axisGold.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - News Content

    @ViewBuilder
    private var newsContent: some View {
        if store.isLoadingNews && store.newsArticles.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(Color.axisGold)
                Text("Loading articles...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if store.newsArticles.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "newspaper")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No articles available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Refresh") { store.send(.refreshNews) }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.axisGold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            let sorted = store.sortedArticles
            let startIndex = min(store.newsPage * store.articlesPerPage, sorted.count)
            let endIndex = min(startIndex + store.articlesPerPage, sorted.count)
            let pageArticles = startIndex < endIndex ? Array(sorted[startIndex..<endIndex]) : []
            let totalPages = max(1, Int(ceil(Double(sorted.count) / Double(store.articlesPerPage))))
            let isLastLoadedPage = store.newsPage >= totalPages - 1
            let canGoNext = store.newsPage < store.maxPages - 1

            ForEach(Array(pageArticles.enumerated()), id: \.element.id) { index, article in
                let readMin = max(1, article.wordCount / 200)
                let meta = [article.publishedDateString, "\(readMin) min read"]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                Button { store.send(.openArticle(article.url)) } label: {
                    if index == 0 {
                        AxisCoverCard(
                            imageURL: article.imageURL.flatMap { URL(string: $0) },
                            eyebrow: "Featured · \(article.source)",
                            title: article.title,
                            meta: meta,
                            seed: article.source,
                            icon: "newspaper.fill",
                            height: 280
                        )
                    } else {
                        AxisThumbnailCard(
                            imageURL: article.imageURL.flatMap { URL(string: $0) },
                            eyebrow: article.source,
                            title: article.title,
                            meta: meta,
                            seed: article.source,
                            icon: "newspaper.fill"
                        )
                    }
                }
                .buttonStyle(.axisPressable)
                .axisAppear(delay: Double(min(index, 6)) * 0.05)
            }

            // Loading indicator when fetching more
            if store.isLoadingNews {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.axisGold)
                    Text("Loading more articles...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            }

            // Pagination controls
            HStack(spacing: 16) {
                Button {
                    store.send(.previousNewsPage)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(store.newsPage > 0 ? Color.axisGold : .gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(store.newsPage > 0 ? Color.axisGold.opacity(0.12) : Color(.systemGray5))
                    .clipShape(Capsule())
                }
                .disabled(store.newsPage == 0)

                Text("Page \(store.newsPage + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 60)

                Button {
                    store.send(.nextNewsPage)
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(canGoNext ? Color.axisGold : .gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(canGoNext ? Color.axisGold.opacity(0.12) : Color(.systemGray5))
                    .clipShape(Capsule())
                }
                .disabled(!canGoNext)
            }
            .padding(.top, 8)

            Text("\(sorted.count) articles loaded")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
    }
}
