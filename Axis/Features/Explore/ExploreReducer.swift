import ComposableArchitecture
import Foundation
import MapKit

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
        var surpriseMePlaces: [PlaceState] = []
        var showSurpriseMe = false
        var activeStatFilter: StatFilter?
        var nearbyResults: [NearbyPlace] = []
        var searchResults: [NearbyPlace] = []
        var isSearchingNearby = false
        // Location bar
        var locationBarText = ""
        var locationDisplayName = ""
        var isSearchingLocation = false
        var isUsingCustomLocation = false
        // Surprise Me from MKLocalSearch
        var surpriseMeResults: [SurpriseResult] = []
        var isLoadingSurpriseMe = false
        // Place detail
        var selectedPlaceId: UUID?

        enum StatFilter: String, Equatable {
            case favorites
            case visited
            case bucketList
        }

        struct NearbyPlace: Equatable, Identifiable {
            let id = UUID()
            var name: String
            var address: String
            var category: String
            var phoneNumber: String = ""
            var websiteURL: String = ""
        }

        struct SurpriseResult: Equatable, Identifiable {
            let id = UUID()
            var name: String
            var category: String
            var address: String
            var latitude: Double
            var longitude: Double

            var categoryIcon: String {
                switch category {
                case "dining": return "fork.knife"
                case "events": return "ticket.fill"
                case "activities": return "figure.hiking"
                case "travel": return "airplane"
                case "shopping": return "bag.fill"
                case "coffee": return "cup.and.saucer.fill"
                default: return "mappin"
                }
            }
        }

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
            var phoneNumber: String = ""
            var websiteURL: String = ""
            var hoursOfOperation: String = ""
            var placeDescription: String = ""

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

            // Apply category filter
            if let key = selectedCategory.filterKey {
                result = result.filter { $0.category == key }
            }

            // Apply stat filter
            if let statFilter = activeStatFilter {
                switch statFilter {
                case .favorites:
                    result = result.filter(\.isFavorite)
                case .visited:
                    result = result.filter(\.isVisited)
                case .bucketList:
                    result = result.filter { !$0.isVisited && !$0.isFavorite }
                }
            }

            // Apply search
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
        case dismissAddPlace
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
        case shuffleSurpriseMe
        case statFilterTapped(State.StatFilter)
        case searchNearby
        case nearbyResultsLoaded([State.NearbyPlace])
        case searchResultsLoaded([State.NearbyPlace])
        case addNearbyPlace(State.NearbyPlace)
        // Location bar
        case locationBarTextChanged(String)
        case locationSearchSubmitted
        case locationSearchCompleted(name: String, success: Bool)
        case useMyLocation
        // Surprise Me from search
        case surpriseMeResultsLoaded([State.SurpriseResult])
        case saveSurpriseResult(State.SurpriseResult)
        // Internal: update location display name from GPS
        case locationDisplayNameUpdated(String)
        // Place detail
        case selectPlace(UUID?)
        case updatePlaceRating(UUID, Int)
        case updatePlaceNotes(UUID, String)
        case updatePlaceCategory(UUID, String)
        case updatePlacePhone(UUID, String)
        case updatePlaceWebsite(UUID, String)
        case updatePlaceHours(UUID, String)
        case updatePlaceDescription(UUID, String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let persistence = PersistenceService.shared
                // Clear old saved places to start fresh
                persistence.deleteAllSavedPlaces()
                state.places = []
                return .run { send in
                    // Request location permission and trigger a fresh GPS fix
                    await MainActor.run {
                        LocationService.shared.requestPermission()
                        LocationService.shared.requestLocation()
                    }
                    // Wait up to 10 seconds for location to resolve
                    var location: CLLocation?
                    for _ in 0..<20 {
                        try? await Task.sleep(for: .milliseconds(500))
                        location = await MainActor.run { LocationService.shared.effectiveLocation }
                        if location != nil { break }
                    }
                    // Update display name from resolved location
                    let name = await MainActor.run { LocationService.shared.currentLocationName }
                    if !name.isEmpty {
                        await send(.locationDisplayNameUpdated(name))
                    }
                    // Now trigger nearby search
                    await send(.searchNearby)
                }

            case let .categoryChanged(category):
                state.selectedCategory = category
                return .send(.searchNearby)

            case let .searchTextChanged(text):
                state.searchText = text
                guard text.count >= 2 else {
                    state.searchResults = []
                    return .none
                }
                // Debounced search via MKLocalSearch
                return .run { send in
                    try await Task.sleep(for: .milliseconds(300))
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = text
                    let location = await MainActor.run { LocationService.shared.effectiveLocation }
                    if let location {
                        request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 50000, longitudinalMeters: 50000)
                    }
                    let search = MKLocalSearch(request: request)
                    do {
                        let response = try await search.start()
                        let results = response.mapItems.prefix(5).map { item in
                            State.NearbyPlace(
                                name: item.name ?? "Unknown",
                                address: item.placemark.title ?? "",
                                category: Self.categorizeMapItem(item),
                                phoneNumber: item.phoneNumber ?? "",
                                websiteURL: item.url?.absoluteString ?? ""
                            )
                        }
                        await send(.searchResultsLoaded(Array(results)))
                    } catch {
                        await send(.searchResultsLoaded([]))
                    }
                }
                .cancellable(id: SearchDebounceID.search)

            case .toggleAddPlace:
                state.showAddPlace.toggle()
                if state.showAddPlace {
                    state.newPlaceName = ""
                    state.newPlaceCategory = "dining"
                    state.newPlaceAddress = ""
                    state.newPlaceNotes = ""
                }
                return .none

            case .dismissAddPlace:
                state.showAddPlace = false
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
                // Find the nearby/search result to get phone/website
                let matchedNearby = state.nearbyResults.first { $0.name == state.newPlaceName }
                    ?? state.searchResults.first { $0.name == state.newPlaceName }
                let place = SavedPlace(
                    name: state.newPlaceName,
                    category: state.newPlaceCategory,
                    address: state.newPlaceAddress,
                    notes: state.newPlaceNotes,
                    phoneNumber: matchedNearby?.phoneNumber ?? "",
                    websiteURL: matchedNearby?.websiteURL ?? ""
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
                    isFavorite: place.isFavorite,
                    phoneNumber: place.phoneNumber,
                    websiteURL: place.websiteURL
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
                state.isLoadingSurpriseMe = true
                state.showSurpriseMe = true
                HapticService.impact(.heavy)
                return .run { send in
                    let categories = ["restaurant", "coffee shop", "park", "entertainment", "shopping", "bar"]
                    let randomCategory = categories.randomElement() ?? "restaurant"
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = randomCategory
                    let location = await MainActor.run { LocationService.shared.effectiveLocation }
                    if let location {
                        request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 15000, longitudinalMeters: 15000)
                    }
                    let search = MKLocalSearch(request: request)
                    do {
                        let response = try await search.start()
                        let shuffled = response.mapItems.shuffled()
                        let results = shuffled.prefix(3).map { item in
                            State.SurpriseResult(
                                name: item.name ?? "Unknown",
                                category: Self.categorizeMapItem(item),
                                address: item.placemark.title ?? "",
                                latitude: item.placemark.coordinate.latitude,
                                longitude: item.placemark.coordinate.longitude
                            )
                        }
                        await send(.surpriseMeResultsLoaded(Array(results)))
                    } catch {
                        await send(.surpriseMeResultsLoaded([]))
                    }
                }

            case let .surpriseMeResultsLoaded(results):
                state.surpriseMeResults = results
                state.isLoadingSurpriseMe = false
                return .none

            case .shuffleSurpriseMe:
                state.isLoadingSurpriseMe = true
                HapticService.impact(.light)
                return .run { send in
                    let categories = ["restaurant", "coffee shop", "park", "entertainment", "shopping", "bar", "museum", "gym", "bakery", "nightlife"]
                    let randomCategory = categories.randomElement() ?? "restaurant"
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = randomCategory
                    let location = await MainActor.run { LocationService.shared.effectiveLocation }
                    if let location {
                        request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 15000, longitudinalMeters: 15000)
                    }
                    let search = MKLocalSearch(request: request)
                    do {
                        let response = try await search.start()
                        let shuffled = response.mapItems.shuffled()
                        let results = shuffled.prefix(3).map { item in
                            State.SurpriseResult(
                                name: item.name ?? "Unknown",
                                category: Self.categorizeMapItem(item),
                                address: item.placemark.title ?? "",
                                latitude: item.placemark.coordinate.latitude,
                                longitude: item.placemark.coordinate.longitude
                            )
                        }
                        await send(.surpriseMeResultsLoaded(Array(results)))
                    } catch {
                        await send(.surpriseMeResultsLoaded([]))
                    }
                }

            case .dismissSurpriseMe:
                state.showSurpriseMe = false
                state.surpriseMeResults = []
                state.surpriseMePlaces = []
                return .none

            case let .statFilterTapped(filter):
                if state.activeStatFilter == filter {
                    state.activeStatFilter = nil
                } else {
                    state.activeStatFilter = filter
                }
                HapticService.selection()
                return .none

            case .searchNearby:
                state.isSearchingNearby = true
                state.nearbyResults = []
                let selectedCategory = state.selectedCategory
                let locationName = state.locationDisplayName
                return .run { send in
                    // Wait for location if not yet available
                    var location = await MainActor.run { LocationService.shared.effectiveLocation }
                    if location == nil {
                        await MainActor.run {
                            LocationService.shared.requestPermission()
                            LocationService.shared.requestLocation()
                        }
                        // Retry up to 10 seconds waiting for location
                        for _ in 0..<20 {
                            try? await Task.sleep(for: .milliseconds(500))
                            location = await MainActor.run { LocationService.shared.effectiveLocation }
                            if location != nil { break }
                        }
                    }
                    guard let loc = location else {
                        await send(.nearbyResultsLoaded([]))
                        return
                    }
                    let queries = Self.queriesForCategory(selectedCategory)
                    let forcedCategory = Self.fixedCategoryKey(for: selectedCategory)
                    let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 12000, longitudinalMeters: 12000)
                    var collected: [State.NearbyPlace] = []
                    var seen = Set<String>()

                    for query in queries {
                        let request = MKLocalSearch.Request()
                        if !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            request.naturalLanguageQuery = "\(query) in \(locationName)"
                        } else {
                            request.naturalLanguageQuery = query
                        }
                        request.region = region
                        let search = MKLocalSearch(request: request)
                        do {
                            let response = try await search.start()
                            for item in response.mapItems {
                                let name = item.name ?? "Unknown"
                                let address = item.placemark.title ?? ""
                                let key = "\(name.lowercased())|\(address.lowercased())"
                                guard !seen.contains(key) else { continue }
                                seen.insert(key)
                                collected.append(State.NearbyPlace(
                                    name: name,
                                    address: address,
                                    category: forcedCategory ?? Self.categorizeMapItem(item),
                                    phoneNumber: item.phoneNumber ?? "",
                                    websiteURL: item.url?.absoluteString ?? ""
                                ))
                                if collected.count == 12 { break }
                            }
                        } catch {
                            continue
                        }
                        if collected.count == 12 { break }
                    }
                    await send(.nearbyResultsLoaded(collected))
                }

            case let .nearbyResultsLoaded(results):
                state.nearbyResults = results
                state.isSearchingNearby = false
                return .run { send in
                    let locName = await MainActor.run { LocationService.shared.currentLocationName }
                    if !locName.isEmpty {
                        await send(.locationDisplayNameUpdated(locName))
                    }
                }

            case let .searchResultsLoaded(results):
                state.searchResults = results
                return .none

            case let .addNearbyPlace(nearby):
                // Save directly instead of showing add form
                let place = SavedPlace(
                    name: nearby.name,
                    category: nearby.category,
                    address: nearby.address,
                    phoneNumber: nearby.phoneNumber,
                    websiteURL: nearby.websiteURL
                )
                PersistenceService.shared.saveSavedPlace(place)
                state.places.append(State.PlaceState(
                    id: place.uuid,
                    name: place.name,
                    category: place.category,
                    address: place.address,
                    notes: "",
                    rating: 0,
                    isVisited: false,
                    isFavorite: false,
                    phoneNumber: nearby.phoneNumber,
                    websiteURL: nearby.websiteURL
                ))
                HapticService.notification(.success)
                return .none

            // MARK: - Location Bar

            case let .locationBarTextChanged(text):
                state.locationBarText = text
                return .none

            case .locationSearchSubmitted:
                let query = state.locationBarText.trimmingCharacters(in: .whitespaces)
                guard !query.isEmpty else { return .none }
                state.isSearchingLocation = true
                return .run { send in
                    let success = await LocationService.shared.searchCity(query)
                    let name = await MainActor.run { LocationService.shared.currentLocationName }
                    await send(.locationSearchCompleted(name: name, success: success))
                }

            case let .locationSearchCompleted(name, success):
                state.isSearchingLocation = false
                if success {
                    state.locationDisplayName = name
                    state.isUsingCustomLocation = true
                    state.locationBarText = ""
                    state.searchResults = []
                    // Refresh nearby with new location
                    return .send(.searchNearby)
                }
                return .none

            case .useMyLocation:
                state.isUsingCustomLocation = false
                state.locationBarText = ""
                state.locationDisplayName = "Current Location"
                return .run { send in
                    await MainActor.run {
                        LocationService.shared.resetToCurrentLocation()
                        LocationService.shared.requestLocation()
                    }
                    // Wait for GPS to deliver a fresh location
                    for _ in 0..<20 {
                        try? await Task.sleep(for: .milliseconds(500))
                        let loc = await MainActor.run { LocationService.shared.currentLocation }
                        if loc != nil { break }
                    }
                    let locName = await MainActor.run { LocationService.shared.currentLocationName }
                    if !locName.isEmpty {
                        await send(.locationDisplayNameUpdated(locName))
                    }
                    await send(.searchNearby)
                }

            case let .saveSurpriseResult(result):
                let place = SavedPlace(
                    name: result.name,
                    category: result.category,
                    address: result.address
                )
                PersistenceService.shared.saveSavedPlace(place)
                state.places.append(State.PlaceState(
                    id: place.uuid,
                    name: place.name,
                    category: place.category,
                    address: place.address,
                    notes: "",
                    rating: 0,
                    isVisited: false,
                    isFavorite: false
                ))
                HapticService.notification(.success)
                return .none

            case let .locationDisplayNameUpdated(name):
                if !name.isEmpty {
                    state.locationDisplayName = name
                }
                return .none

            // MARK: - Place Detail

            case let .selectPlace(id):
                state.selectedPlaceId = id
                return .none

            case let .updatePlaceRating(id, rating):
                if let index = state.places.firstIndex(where: { $0.id == id }) {
                    state.places[index].rating = rating
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSavedPlaces()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.rating = rating
                        persistence.updateSavedPlaces()
                    }
                }
                return .none

            case let .updatePlaceNotes(id, notes):
                if let index = state.places.firstIndex(where: { $0.id == id }) {
                    state.places[index].notes = notes
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSavedPlaces()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.notes = notes
                        persistence.updateSavedPlaces()
                    }
                }
                return .none

            case let .updatePlaceCategory(id, category):
                if let index = state.places.firstIndex(where: { $0.id == id }) {
                    state.places[index].category = category
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSavedPlaces()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.category = category
                        persistence.updateSavedPlaces()
                    }
                }
                return .none

            case let .updatePlacePhone(id, phone):
                if let index = state.places.firstIndex(where: { $0.id == id }) {
                    state.places[index].phoneNumber = phone
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSavedPlaces()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.phoneNumber = phone
                        persistence.updateSavedPlaces()
                    }
                }
                return .none

            case let .updatePlaceWebsite(id, url):
                if let index = state.places.firstIndex(where: { $0.id == id }) {
                    state.places[index].websiteURL = url
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSavedPlaces()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.websiteURL = url
                        persistence.updateSavedPlaces()
                    }
                }
                return .none

            case let .updatePlaceHours(id, hours):
                if let index = state.places.firstIndex(where: { $0.id == id }) {
                    state.places[index].hoursOfOperation = hours
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSavedPlaces()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.hoursOfOperation = hours
                        persistence.updateSavedPlaces()
                    }
                }
                return .none

            case let .updatePlaceDescription(id, desc):
                if let index = state.places.firstIndex(where: { $0.id == id }) {
                    state.places[index].placeDescription = desc
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSavedPlaces()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.placeDescription = desc
                        persistence.updateSavedPlaces()
                    }
                }
                return .none
            }
        }
    }

    private enum SearchDebounceID { case search }

    private static func queriesForCategory(_ category: State.Category) -> [String] {
        switch category {
        case .all:
            return ["restaurants", "events", "things to do", "travel attractions"]
        case .dining:
            return ["restaurants", "coffee shops", "brunch", "dessert"]
        case .events:
            return ["live music", "theaters", "events", "museums"]
        case .activities:
            return ["parks", "fitness", "hiking", "activities"]
        case .travel:
            return ["hotels", "landmarks", "tourist attractions", "airports"]
        }
    }

    private static func fixedCategoryKey(for category: State.Category) -> String? {
        switch category {
        case .all: return nil
        case .dining: return "dining"
        case .events: return "events"
        case .activities: return "activities"
        case .travel: return "travel"
        }
    }

    private static func categorizeMapItem(_ item: MKMapItem) -> String {
        if let category = item.pointOfInterestCategory {
            switch category {
            case .restaurant, .bakery, .cafe, .brewery, .winery:
                return "dining"
            case .nightlife, .theater, .movieTheater, .museum:
                return "events"
            case .park, .beach, .nationalPark, .fitnessCenter:
                return "activities"
            case .airport, .hotel, .publicTransport:
                return "travel"
            default:
                return "activities"
            }
        }
        return "dining"
    }

}
