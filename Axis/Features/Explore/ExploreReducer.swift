import ComposableArchitecture
import Foundation

@Reducer
struct ExploreReducer {
    @ObservableState
    struct State: Equatable {
        var selectedCategory: Category = .all
        var places: [PlaceState] = []
        var showAddPlace = false
        var newPlaceName = ""
        var newPlaceCategory = "dining"
        var newPlaceAddress = ""
        var newPlaceNotes = ""
        var searchText = ""
        var surpriseMePlace: PlaceState?
        var showSurpriseMe = false

        enum Category: String, CaseIterable, Equatable {
            case all = "All"
            case dining = "Dining"
            case events = "Events"
            case activities = "Activities"
            case travel = "Travel"

            var icon: String {
                switch self {
                case .all: return "square.grid.2x2.fill"
                case .dining: return "fork.knife"
                case .events: return "ticket.fill"
                case .activities: return "figure.hiking"
                case .travel: return "airplane"
                }
            }

            var filterKey: String? {
                switch self {
                case .all: return nil
                default: return rawValue.lowercased()
                }
            }
        }

        struct PlaceState: Equatable, Identifiable {
            let id: UUID
            var name: String
            var category: String
            var address: String
            var notes: String
            var rating: Int
            var isVisited: Bool
            var isFavorite: Bool

            var categoryIcon: String {
                switch category {
                case "dining": return "fork.knife"
                case "events": return "ticket.fill"
                case "activities": return "figure.hiking"
                case "travel": return "airplane"
                default: return "mappin"
                }
            }
        }

        var filteredPlaces: [PlaceState] {
            var result = places
            if let key = selectedCategory.filterKey {
                result = result.filter { $0.category == key }
            }
            if !searchText.isEmpty {
                result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.notes.localizedCaseInsensitiveContains(searchText) }
            }
            return result.sorted { $0.isFavorite && !$1.isFavorite }
        }

        var favoriteCount: Int {
            places.filter(\.isFavorite).count
        }

        var visitedCount: Int {
            places.filter(\.isVisited).count
        }

        var bucketListCount: Int {
            places.filter { !$0.isVisited }.count
        }
    }

    enum Action: Equatable {
        case onAppear
        case categoryChanged(State.Category)
        case searchTextChanged(String)
        case toggleAddPlace
        case newPlaceNameChanged(String)
        case newPlaceCategoryChanged(String)
        case newPlaceAddressChanged(String)
        case newPlaceNotesChanged(String)
        case addPlace
        case deletePlace(UUID)
        case toggleFavorite(UUID)
        case toggleVisited(UUID)
        case surpriseMeTapped
        case dismissSurpriseMe
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let persistence = PersistenceService.shared
                let stored = persistence.fetchSavedPlaces()
                if stored.isEmpty {
                    let samples = Self.samplePlaces()
                    for s in samples {
                        let place = SavedPlace(name: s.name, category: s.category, address: s.address, notes: s.notes, rating: s.rating, isVisited: s.isVisited, isFavorite: s.isFavorite)
                        persistence.saveSavedPlace(place)
                        state.places.append(State.PlaceState(id: place.uuid, name: place.name, category: place.category, address: place.address, notes: place.notes, rating: place.rating, isVisited: place.isVisited, isFavorite: place.isFavorite))
                    }
                } else {
                    state.places = stored.map { p in
                        State.PlaceState(id: p.uuid, name: p.name, category: p.category, address: p.address, notes: p.notes, rating: p.rating, isVisited: p.isVisited, isFavorite: p.isFavorite)
                    }
                }
                return .none

            case let .categoryChanged(category):
                state.selectedCategory = category
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case .toggleAddPlace:
                state.showAddPlace.toggle()
                if state.showAddPlace {
                    state.newPlaceName = ""
                    state.newPlaceCategory = "dining"
                    state.newPlaceAddress = ""
                    state.newPlaceNotes = ""
                }
                return .none

            case let .newPlaceNameChanged(name):
                state.newPlaceName = name
                return .none

            case let .newPlaceCategoryChanged(category):
                state.newPlaceCategory = category
                return .none

            case let .newPlaceAddressChanged(address):
                state.newPlaceAddress = address
                return .none

            case let .newPlaceNotesChanged(notes):
                state.newPlaceNotes = notes
                return .none

            case .addPlace:
                guard !state.newPlaceName.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return .none
                }
                let place = SavedPlace(
                    name: state.newPlaceName,
                    category: state.newPlaceCategory,
                    address: state.newPlaceAddress,
                    notes: state.newPlaceNotes
                )
                PersistenceService.shared.saveSavedPlace(place)
                state.places.append(State.PlaceState(
                    id: place.uuid,
                    name: place.name,
                    category: place.category,
                    address: place.address,
                    notes: place.notes,
                    rating: place.rating,
                    isVisited: place.isVisited,
                    isFavorite: place.isFavorite
                ))
                state.showAddPlace = false
                HapticService.notification(.success)
                return .none

            case let .deletePlace(id):
                state.places.removeAll { $0.id == id }
                let persistence = PersistenceService.shared
                let stored = persistence.fetchSavedPlaces()
                if let match = stored.first(where: { $0.uuid == id }) {
                    persistence.deleteSavedPlace(match)
                }
                return .none

            case let .toggleFavorite(id):
                if let index = state.places.firstIndex(where: { $0.id == id }) {
                    state.places[index].isFavorite.toggle()
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSavedPlaces()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.isFavorite = state.places[index].isFavorite
                        persistence.updateSavedPlaces()
                    }
                    HapticService.impact(.light)
                }
                return .none

            case let .toggleVisited(id):
                if let index = state.places.firstIndex(where: { $0.id == id }) {
                    state.places[index].isVisited.toggle()
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSavedPlaces()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.isVisited = state.places[index].isVisited
                        persistence.updateSavedPlaces()
                    }
                    if state.places[index].isVisited {
                        HapticService.celebration()
                    }
                }
                return .none

            case .surpriseMeTapped:
                let unvisited = state.places.filter { !$0.isVisited }
                if let random = unvisited.randomElement() {
                    state.surpriseMePlace = random
                    state.showSurpriseMe = true
                    HapticService.impact(.heavy)
                }
                return .none

            case .dismissSurpriseMe:
                state.showSurpriseMe = false
                state.surpriseMePlace = nil
                return .none
            }
        }
    }

    private static func samplePlaces() -> [State.PlaceState] {
        [
            .init(id: UUID(), name: "Franklin Barbecue", category: "dining", address: "900 E 11th St, Austin", notes: "Best brisket in Texas. Go early.", rating: 5, isVisited: true, isFavorite: true),
            .init(id: UUID(), name: "Uchi", category: "dining", address: "801 S Lamar Blvd, Austin", notes: "Upscale Japanese. Date night spot.", rating: 5, isVisited: false, isFavorite: true),
            .init(id: UUID(), name: "ACL Music Festival", category: "events", address: "Zilker Park, Austin", notes: "October annual. Get 3-day passes.", rating: 0, isVisited: false, isFavorite: false),
            .init(id: UUID(), name: "Barton Springs Pool", category: "activities", address: "2201 Barton Springs Rd", notes: "Natural spring-fed pool. Family friendly.", rating: 4, isVisited: true, isFavorite: false),
            .init(id: UUID(), name: "Big Bend National Park", category: "travel", address: "Big Bend, TX", notes: "Weekend camping trip. Stars are incredible.", rating: 0, isVisited: false, isFavorite: true),
            .init(id: UUID(), name: "Kemah Boardwalk", category: "activities", address: "Kemah, TX", notes: "Rides and seafood. Great for kids.", rating: 0, isVisited: false, isFavorite: false),
        ]
    }
}
