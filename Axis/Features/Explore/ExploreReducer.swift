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
        // Recently viewed
        var recentlyViewed: [NearbyPlace] = []
        var searchRadiusMeters: Double = 12000
        var isLoadingMore: Bool = false

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
            var isVerified: Bool = false
            var rating: Double = 0.0
            var reviewCount: Int = 0
            var todayHours: String = ""
            var price: String = ""
            var imageURL: String = ""
            var yelpURL: String = ""
        }

        struct SurpriseResult: Equatable, Identifiable {
            let id = UUID()
            var name: String
            var category: String
            var address: String
            var latitude: Double
            var longitude: Double
            var phoneNumber: String = ""
            var websiteURL: String = ""
            var isVerified: Bool = false
            var rating: Double = 0.0
            var reviewCount: Int = 0
            var todayHours: String = ""
            var price: String = ""

            var categoryIcon: String {
                switch category {
                case "dining": return "fork.knife"
                case "events": return "ticket.fill"
                case "activities": return "figure.hiking"
                case "travel": return "airplane"
                case "shopping": return "bag.fill"
                case "coffee": return "cup.and.saucer.fill"
                case "blackOwned": return "hand.raised.fill"
                case "kids": return "figure.and.child.holdinghands"
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
            case blackOwned = "Black-Owned"
            case kids = "Kids"

            var icon: String {
                switch self {
                case .all: return "square.grid.2x2.fill"
                case .dining: return "fork.knife"
                case .events: return "ticket.fill"
                case .activities: return "figure.hiking"
                case .travel: return "airplane"
                case .blackOwned: return "hand.raised.fill"
                case .kids: return "figure.and.child.holdinghands"
                }
            }

            var filterKey: String? {
                switch self {
                case .all: return nil
                case .blackOwned: return "blackOwned"
                case .kids: return "kids"
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
                case "blackOwned": return "hand.raised.fill"
                case "kids": return "figure.and.child.holdinghands"
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
        case loadMoreNearby
        case moreNearbyLoaded([State.NearbyPlace])
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
        case surpriseResultsEnriched([State.SurpriseResult])
        // Internal: update location display name from GPS
        case locationDisplayNameUpdated(String)
        // Yelp enrichment
        case enrichWithYelp
        case yelpEnriched([State.NearbyPlace])
        // Recently viewed
        case viewedPlace(State.NearbyPlace)
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
                // Load any saved places
                let saved = persistence.fetchSavedPlaces()
                state.places = saved.map { p in
                    State.PlaceState(
                        id: p.uuid, name: p.name, category: p.category,
                        address: p.address, notes: p.notes, rating: p.rating,
                        isVisited: p.isVisited, isFavorite: p.isFavorite
                    )
                }
                return .run { send in
                    // Request location
                    await MainActor.run {
                        LocationService.shared.requestPermission()
                        LocationService.shared.requestLocation()
                    }
                    // Wait up to 2 seconds for location
                    var location: CLLocation?
                    for _ in 0..<4 {
                        try? await Task.sleep(for: .milliseconds(500))
                        location = await MainActor.run { LocationService.shared.effectiveLocation }
                        if location != nil { break }
                    }
                    let name = await MainActor.run { LocationService.shared.currentLocationName }
                    if !name.isEmpty {
                        await send(.locationDisplayNameUpdated(name))
                    }
                    // Search nearby — will show results even without location using default area
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
                                websiteURL: item.url?.absoluteString ?? "",
                                isVerified: !(item.url == nil && (item.phoneNumber ?? "").isEmpty)
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
                                longitude: item.placemark.coordinate.longitude,
                                phoneNumber: item.phoneNumber ?? "",
                                websiteURL: item.url?.absoluteString ?? "",
                                isVerified: !(item.url == nil && (item.phoneNumber ?? "").isEmpty)
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
                let locationName = state.locationDisplayName
                return .run { send in
                    let yelp = YelpService.shared
                    let location = locationName.isEmpty ? "Marshall, TX" : locationName
                    var enriched = results
                    for i in 0..<enriched.count {
                        let matches = await yelp.searchBusinesses(term: enriched[i].name, location: location, limit: 1)
                        if let match = matches.first {
                            enriched[i].rating = match.rating
                            enriched[i].reviewCount = match.reviewCount
                            enriched[i].todayHours = match.todayHours
                            enriched[i].price = match.price
                            if enriched[i].phoneNumber.isEmpty { enriched[i].phoneNumber = match.phone }
                            // Don't overwrite real website with Yelp URL — keep them separate
                        }
                    }
                    await send(.surpriseResultsEnriched(enriched))
                }

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
                                longitude: item.placemark.coordinate.longitude,
                                phoneNumber: item.phoneNumber ?? "",
                                websiteURL: item.url?.absoluteString ?? "",
                                isVerified: !(item.url == nil && (item.phoneNumber ?? "").isEmpty)
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
                        // Retry up to 3 seconds waiting for location
                        for _ in 0..<6 {
                            try? await Task.sleep(for: .milliseconds(500))
                            location = await MainActor.run { LocationService.shared.effectiveLocation }
                            if location != nil { break }
                        }
                    }
                    // Default to Marshall, TX (Wiley University) if no GPS
                    let loc = location ?? CLLocation(latitude: 32.5449, longitude: -94.3674)
                    if location == nil {
                        await send(.locationDisplayNameUpdated("Marshall, TX"))
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
                                    websiteURL: item.url?.absoluteString ?? "",
                                    isVerified: !(item.url == nil && (item.phoneNumber ?? "").isEmpty)
                                ))
                                if collected.count == 30 { break }
                            }
                        } catch {
                            continue
                        }
                        if collected.count == 30 { break }
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
                    await send(.enrichWithYelp)
                }

            case .loadMoreNearby:
                guard !state.isLoadingMore else { return .none }
                state.isLoadingMore = true
                state.searchRadiusMeters += 15000
                let selectedCategory = state.selectedCategory
                let locationName = state.locationDisplayName
                let radius = state.searchRadiusMeters
                let existingNames = Set(state.nearbyResults.map { $0.name.lowercased() })
                return .run { send in
                    let location = await MainActor.run { LocationService.shared.effectiveLocation }
                    let loc = location ?? CLLocation(latitude: 32.5449, longitude: -94.3674)
                    let queries = Self.queriesForCategory(selectedCategory)
                    let forcedCategory = Self.fixedCategoryKey(for: selectedCategory)
                    let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: radius, longitudinalMeters: radius)
                    var collected: [State.NearbyPlace] = []

                    for query in queries {
                        let request = MKLocalSearch.Request()
                        if !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            request.naturalLanguageQuery = "\(query) near \(locationName)"
                        } else {
                            request.naturalLanguageQuery = query
                        }
                        request.region = region
                        let search = MKLocalSearch(request: request)
                        do {
                            let response = try await search.start()
                            for item in response.mapItems {
                                let name = item.name ?? "Unknown"
                                guard !existingNames.contains(name.lowercased()) else { continue }
                                collected.append(State.NearbyPlace(
                                    name: name,
                                    address: item.placemark.title ?? "",
                                    category: forcedCategory ?? Self.categorizeMapItem(item),
                                    phoneNumber: item.phoneNumber ?? "",
                                    websiteURL: item.url?.absoluteString ?? "",
                                    isVerified: !(item.url == nil && (item.phoneNumber ?? "").isEmpty)
                                ))
                                if collected.count == 15 { break }
                            }
                        } catch { continue }
                        if collected.count == 15 { break }
                    }
                    await MainActor.run {
                        // Append to existing results
                    }
                    // Use a new action to append
                    await send(.moreNearbyLoaded(collected))
                }

            case let .moreNearbyLoaded(more):
                state.nearbyResults.append(contentsOf: more)
                state.isLoadingMore = false
                return .none

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
                    state.nearbyResults = []
                    state.recentlyViewed = []
                    state.searchRadiusMeters = 12000
                    // Refresh nearby with new location after a brief delay for LocationService to update
                    return .run { send in
                        try? await Task.sleep(for: .milliseconds(200))
                        await send(.searchNearby)
                    }
                }
                return .none

            case .useMyLocation:
                state.isUsingCustomLocation = false
                state.locationBarText = ""
                state.locationDisplayName = "Current Location"
                state.nearbyResults = []
                state.recentlyViewed = []
                state.searchRadiusMeters = 12000
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

            case let .surpriseResultsEnriched(enriched):
                state.surpriseMeResults = enriched
                return .none

            case let .locationDisplayNameUpdated(name):
                if !name.isEmpty {
                    state.locationDisplayName = name
                }
                return .none

            // MARK: - Yelp Enrichment

            case .enrichWithYelp:
                let locationName = state.locationDisplayName
                let currentResults = state.nearbyResults
                guard !currentResults.isEmpty else { return .none }
                return .run { send in
                    let yelp = YelpService.shared
                    let location = locationName.isEmpty ? "Marshall, TX" : locationName
                    let toEnrich = Array(currentResults.prefix(10))
                    // Parallel Yelp lookups
                    let enrichedData = await withTaskGroup(of: (Int, YelpService.YelpBusiness?).self) { group in
                        for (i, place) in toEnrich.enumerated() {
                            group.addTask {
                                let results = await yelp.searchBusinesses(term: place.name, location: location, limit: 1)
                                return (i, results.first)
                            }
                        }
                        var data: [(Int, YelpService.YelpBusiness?)] = []
                        for await result in group { data.append(result) }
                        return data
                    }
                    var enriched = currentResults
                    for (i, match) in enrichedData {
                        guard let match, i < enriched.count else { continue }
                        enriched[i].rating = match.rating
                        enriched[i].reviewCount = match.reviewCount
                        enriched[i].todayHours = match.todayHours
                        enriched[i].price = match.price
                        if enriched[i].phoneNumber.isEmpty { enriched[i].phoneNumber = match.phone }
                        enriched[i].imageURL = match.imageURL
                        enriched[i].yelpURL = match.yelpURL
                    }
                    await send(.yelpEnriched(enriched))
                }

            case let .yelpEnriched(results):
                state.nearbyResults = results
                return .none

            // MARK: - Recently Viewed

            case let .viewedPlace(place):
                state.recentlyViewed.removeAll { $0.id == place.id }
                state.recentlyViewed.insert(place, at: 0)
                if state.recentlyViewed.count > 5 {
                    state.recentlyViewed = Array(state.recentlyViewed.prefix(5))
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
            return ["live music tonight", "concerts", "comedy shows", "theater performances", "festivals", "events this week", "nightlife", "sports events"]
        case .activities:
            return ["parks", "fitness", "hiking", "activities"]
        case .travel:
            return ["hotels", "landmarks", "tourist attractions", "airports"]
        case .blackOwned:
            return ["Black owned restaurant", "Black owned bar", "Black owned business", "Black owned cafe", "Black owned shop", "African American owned"]
        case .kids:
            return ["children's museum", "playground", "trampoline park", "bowling alley", "arcade", "kids activities", "zoo", "aquarium", "skating rink", "miniature golf"]
        }
    }

    private static func fixedCategoryKey(for category: State.Category) -> String? {
        switch category {
        case .all: return nil
        case .dining: return "dining"
        case .events: return "events"
        case .activities: return "activities"
        case .travel: return "travel"
        case .blackOwned: return "blackOwned"
        case .kids: return "kids"
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
