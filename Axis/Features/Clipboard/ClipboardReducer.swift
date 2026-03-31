import ComposableArchitecture
import Foundation

@Reducer
struct ClipboardReducer {
    @ObservableState
    struct State: Equatable {
        var items: [ClipItem] = []
        var searchText: String = ""
        var selectedFilter: Filter = .all
        var showAddSheet: Bool = false
        var editingItem: ClipItem? = nil

        // Form
        var formContent: String = ""
        var formTitle: String = ""
        var formType: String = "text"
        var formTags: String = ""

        enum Filter: String, CaseIterable {
            case all = "All"
            case links = "Links"
            case snippets = "Snippets"
            case favorites = "Favorites"

            var icon: String {
                switch self {
                case .all: return "tray.full.fill"
                case .links: return "link"
                case .snippets: return "doc.text"
                case .favorites: return "star.fill"
                }
            }
        }

        struct ClipItem: Equatable, Identifiable {
            let id: UUID
            var content: String
            var title: String
            var itemType: String
            var tags: [String]
            var isFavorite: Bool
            var createdAt: Date

            var displayTitle: String {
                if !title.isEmpty { return title }
                if isLink {
                    return content.components(separatedBy: "/").last ?? content
                }
                return String(content.prefix(60))
            }

            var icon: String {
                switch itemType {
                case "link": return "link"
                case "snippet": return "doc.text"
                default: return "doc.on.clipboard"
                }
            }

            var isLink: Bool {
                content.hasPrefix("http://") || content.hasPrefix("https://")
            }
        }

        var filteredItems: [ClipItem] {
            var result = items

            switch selectedFilter {
            case .all: break
            case .links: result = result.filter { $0.itemType == "link" }
            case .snippets: result = result.filter { $0.itemType == "snippet" }
            case .favorites: result = result.filter { $0.isFavorite }
            }

            if !searchText.isEmpty {
                let query = searchText.lowercased()
                result = result.filter {
                    $0.title.lowercased().contains(query) ||
                    $0.content.lowercased().contains(query) ||
                    $0.tags.contains { $0.lowercased().contains(query) }
                }
            }

            return result.sorted { $0.createdAt > $1.createdAt }
        }
    }

    enum Action: Equatable {
        case onAppear
        case itemsLoaded([State.ClipItem])
        case searchTextChanged(String)
        case filterChanged(State.Filter)
        case showAddSheet
        case dismissSheet
        case formContentChanged(String)
        case formTitleChanged(String)
        case formTypeChanged(String)
        case formTagsChanged(String)
        case saveItem
        case editItem(State.ClipItem)
        case deleteItem(State.ClipItem)
        case toggleFavorite(State.ClipItem)
        case pasteFromClipboard
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let fetched = PersistenceService.shared.fetchClipboardItems()
                    let items = fetched.map { item in
                        State.ClipItem(id: item.uuid, content: item.content, title: item.title, itemType: item.itemType, tags: item.tags, isFavorite: item.isFavorite, createdAt: item.createdAt)
                    }
                    await send(.itemsLoaded(items))
                }

            case let .itemsLoaded(items):
                state.items = items
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case let .filterChanged(filter):
                state.selectedFilter = filter
                return .none

            case .showAddSheet:
                state.editingItem = nil
                state.formContent = ""
                state.formTitle = ""
                state.formType = "text"
                state.formTags = ""
                state.showAddSheet = true
                return .none

            case .dismissSheet:
                state.showAddSheet = false
                state.editingItem = nil
                return .none

            case let .formContentChanged(t): state.formContent = t; return .none
            case let .formTitleChanged(t): state.formTitle = t; return .none
            case let .formTypeChanged(t): state.formType = t; return .none
            case let .formTagsChanged(t): state.formTags = t; return .none

            case .pasteFromClipboard:
                if let text = PlatformServices.pasteFromClipboard() {
                    state.formContent = text
                    if text.hasPrefix("http://") || text.hasPrefix("https://") {
                        state.formType = "link"
                    }
                }
                return .none

            case .saveItem:
                let content = state.formContent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty else {
                    state.showAddSheet = false
                    return .none
                }
                let tags = state.formTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                let type = (content.hasPrefix("http://") || content.hasPrefix("https://")) ? "link" : state.formType

                if let editing = state.editingItem {
                    let items = PersistenceService.shared.fetchClipboardItems()
                    if let match = items.first(where: { $0.uuid == editing.id }) {
                        match.content = content
                        match.title = state.formTitle
                        match.itemType = type
                        match.tags = tags
                        PersistenceService.shared.updateClipboardItems()
                    }
                } else {
                    let item = ClipboardItem(
                        content: content,
                        title: state.formTitle,
                        itemType: type,
                        tags: tags
                    )
                    PersistenceService.shared.saveClipboardItem(item)
                }

                state.showAddSheet = false
                state.editingItem = nil
                return .send(.onAppear)

            case let .editItem(item):
                state.editingItem = item
                state.formContent = item.content
                state.formTitle = item.title
                state.formType = item.itemType
                state.formTags = item.tags.joined(separator: ", ")
                state.showAddSheet = true
                return .none

            case let .deleteItem(item):
                let items = PersistenceService.shared.fetchClipboardItems()
                if let match = items.first(where: { $0.uuid == item.id }) {
                    PersistenceService.shared.deleteClipboardItem(match)
                }
                state.items.removeAll { $0.id == item.id }
                return .none

            case let .toggleFavorite(item):
                let items = PersistenceService.shared.fetchClipboardItems()
                if let match = items.first(where: { $0.uuid == item.id }) {
                    match.isFavorite.toggle()
                    PersistenceService.shared.updateClipboardItems()
                }
                if let idx = state.items.firstIndex(where: { $0.id == item.id }) {
                    state.items[idx].isFavorite.toggle()
                }
                return .none
            }
        }
    }
}
