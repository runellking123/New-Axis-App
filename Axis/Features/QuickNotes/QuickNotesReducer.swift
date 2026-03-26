import ComposableArchitecture
import Foundation

@Reducer
struct QuickNotesReducer {
    @ObservableState
    struct State: Equatable {
        var notes: [NoteItem] = []
        var searchText: String = ""
        var showAddSheet: Bool = false
        var editingNote: NoteItem? = nil
        var sortOrder: SortOrder = .newest
        var selectedFolder: Folder = .all

        // Add/Edit form fields
        var formTitle: String = ""
        var formContent: String = ""
        var formColor: String = "yellow"
        var formFolder: Folder = .personal

        enum Folder: String, CaseIterable, Equatable {
            case all = "All"
            case work = "Work"
            case personal = "Personal"
            case lagniappe = "Lagniappe"

            var icon: String {
                switch self {
                case .all: return "tray.full.fill"
                case .work: return "briefcase.fill"
                case .personal: return "person.fill"
                case .lagniappe: return "sparkles"
                }
            }

            /// Folders that can be assigned to a note (excludes "All")
            static var assignable: [Folder] {
                [.work, .personal, .lagniappe]
            }
        }

        enum SortOrder: String, CaseIterable {
            case newest = "Newest"
            case oldest = "Oldest"
            case alphabetical = "A-Z"
        }

        struct NoteItem: Equatable, Identifiable {
            let id: UUID
            var title: String
            var content: String
            var isPinned: Bool
            var color: String
            var folder: String
            var createdAt: Date
            var updatedAt: Date

            var displayTitle: String {
                if !title.isEmpty { return title }
                if let firstLine = content.components(separatedBy: .newlines).first, !firstLine.isEmpty {
                    return String(firstLine.prefix(50))
                }
                return "Untitled Note"
            }

            var preview: String {
                let lines = content.components(separatedBy: .newlines)
                let startIndex = title.isEmpty ? 1 : 0
                let previewLines = lines.dropFirst(startIndex).prefix(3).joined(separator: " ")
                return String(previewLines.prefix(120))
            }
        }

        var filteredNotes: [NoteItem] {
            var result = notes

            // Filter by folder
            if selectedFolder != .all {
                result = result.filter { $0.folder == selectedFolder.rawValue }
            }

            // Filter by search
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                result = result.filter {
                    $0.title.lowercased().contains(query) ||
                    $0.content.lowercased().contains(query)
                }
            }

            // Sort
            switch sortOrder {
            case .newest:
                result.sort { $0.updatedAt > $1.updatedAt }
            case .oldest:
                result.sort { $0.updatedAt < $1.updatedAt }
            case .alphabetical:
                result.sort { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
            }

            // Pinned always on top
            let pinned = result.filter { $0.isPinned }
            let unpinned = result.filter { !$0.isPinned }
            return pinned + unpinned
        }

        func noteCount(for folder: Folder) -> Int {
            if folder == .all { return notes.count }
            return notes.filter { $0.folder == folder.rawValue }.count
        }
    }

    enum Action: Equatable {
        case onAppear
        case loadNotes
        case notesLoaded([State.NoteItem])
        case searchTextChanged(String)
        case sortOrderChanged(State.SortOrder)
        case selectedFolderChanged(State.Folder)
        case showAddSheet
        case dismissSheet
        case formTitleChanged(String)
        case formContentChanged(String)
        case formColorChanged(String)
        case formFolderChanged(State.Folder)
        case saveNote
        case editNote(State.NoteItem)
        case deleteNote(State.NoteItem)
        case togglePin(State.NoteItem)
    }

    @Dependency(\.axisPersistence) var persistence

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.loadNotes)

            case .loadNotes:
                let fetched = persistence.fetchNotes()
                let items = fetched.enumerated().map { index, note in
                    let seed = Int(note.createdAt.timeIntervalSince1970 * 1000) &+ index
                    let stableId = UUID(uuidString: String(format: "%08X-0000-0000-0000-%012X", abs(seed) % 0xFFFFFFFF, abs(seed))) ?? UUID()
                    return State.NoteItem(
                        id: stableId,
                        title: note.title,
                        content: note.content,
                        isPinned: note.isPinned,
                        color: note.color,
                        folder: note.resolvedFolder,
                        createdAt: note.createdAt,
                        updatedAt: note.updatedAt
                    )
                }
                return .send(.notesLoaded(items))

            case let .notesLoaded(items):
                state.notes = items
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case let .sortOrderChanged(order):
                state.sortOrder = order
                return .none

            case let .selectedFolderChanged(folder):
                state.selectedFolder = folder
                return .none

            case .showAddSheet:
                state.editingNote = nil
                state.formTitle = ""
                state.formContent = ""
                state.formColor = "yellow"
                // Default to current folder, unless viewing "All"
                state.formFolder = state.selectedFolder == .all ? .personal : state.selectedFolder
                state.showAddSheet = true
                return .none

            case .dismissSheet:
                state.showAddSheet = false
                state.editingNote = nil
                return .none

            case let .formTitleChanged(text):
                state.formTitle = text
                return .none

            case let .formContentChanged(text):
                state.formContent = text
                return .none

            case let .formColorChanged(color):
                state.formColor = color
                return .none

            case let .formFolderChanged(folder):
                state.formFolder = folder
                return .none

            case .saveNote:
                let title = state.formTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let content = state.formContent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty || !title.isEmpty else {
                    state.showAddSheet = false
                    return .none
                }

                if let editing = state.editingNote {
                    let allNotes = persistence.fetchNotes()
                    if let match = allNotes.first(where: {
                        $0.createdAt == editing.createdAt && $0.content == editing.content
                    }) {
                        match.title = title
                        match.content = content
                        match.color = state.formColor
                        match.folder = state.formFolder.rawValue
                        match.updatedAt = Date()
                        persistence.updateNotes()
                    }
                } else {
                    let note = CapturedNote(
                        title: title,
                        content: content,
                        color: state.formColor,
                        folder: state.formFolder.rawValue
                    )
                    persistence.saveNote(note)
                }

                state.showAddSheet = false
                state.editingNote = nil
                return .send(.loadNotes)

            case let .editNote(item):
                state.editingNote = item
                state.formTitle = item.title
                state.formContent = item.content
                state.formColor = item.color
                state.formFolder = State.Folder(rawValue: item.folder) ?? .personal
                state.showAddSheet = true
                return .none

            case let .deleteNote(item):
                let allNotes = persistence.fetchNotes()
                if let match = allNotes.first(where: {
                    $0.createdAt == item.createdAt && $0.content == item.content
                }) {
                    persistence.deleteNote(match)
                }
                return .send(.loadNotes)

            case let .togglePin(item):
                let allNotes = persistence.fetchNotes()
                if let match = allNotes.first(where: {
                    $0.createdAt == item.createdAt && $0.content == item.content
                }) {
                    match.isPinned.toggle()
                    match.updatedAt = Date()
                    persistence.updateNotes()
                }
                return .send(.loadNotes)
            }
        }
    }
}
