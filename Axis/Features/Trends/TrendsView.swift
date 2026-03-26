import ComposableArchitecture
import SwiftUI

struct TrendsView: View {
    @Bindable var store: StoreOf<TrendsReducer>
    @State private var selectedMetric: MetricSelection?

    struct MetricSelection: Identifiable {
        let id = UUID()
        let name: String
        let value: String
        let unit: String
        let color: Color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                newsCategoryPicker
                newsContent
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("News")
                    .font(.system(size: 18, weight: .bold, design: .serif))
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
            store.send(.loadNews)
        }
    }

    // MARK: - News Category Picker

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
            .padding(.horizontal)
        }
    }

    // MARK: - News Content

    @ViewBuilder
    private var newsContent: some View {
        if store.isLoadingNews {
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
                    let startIndex = store.newsPage * store.articlesPerPage
                    let endIndex = min(startIndex + store.articlesPerPage, store.newsArticles.count)
                    let pageArticles = Array(store.newsArticles[startIndex..<endIndex])
                    let totalPages = max(1, Int(ceil(Double(store.newsArticles.count) / Double(store.articlesPerPage))))

                    ForEach(pageArticles) { article in
                        Button { store.send(.openArticle(article.url)) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(article.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                    HStack(spacing: 6) {
                                        Text(article.source)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.axisGold)
                                        Circle()
                                            .fill(.secondary.opacity(0.3))
                                            .frame(width: 3, height: 3)
                                        Text(article.publishedDate)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(.rect(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

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

                        Text("Page \(store.newsPage + 1) of \(totalPages)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 80)

                        Button {
                            store.send(.nextNewsPage)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(store.newsPage < totalPages - 1 ? Color.axisGold : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(store.newsPage < totalPages - 1 ? Color.axisGold.opacity(0.12) : Color(.systemGray5))
                            .clipShape(Capsule())
                        }
                        .disabled(store.newsPage >= totalPages - 1)
                    }
                    .padding(.top, 8)

                    // Article count
                    Text("\(store.newsArticles.count) articles loaded")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
        }
    }

    // Removed old trend charts/metrics — News tab is now news-only
