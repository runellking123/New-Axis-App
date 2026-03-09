import ComposableArchitecture
import SwiftUI
import UIKit

struct ExploreView: View {
    @Bindable var store: StoreOf<ExploreReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                locationBar
                searchBar
                categoryChips
                mainScrollView
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { exploreToolbar }
            .sheet(isPresented: Binding(
                get: { store.showAddPlace },
                set: { newValue in
                    if !newValue { store.send(.dismissAddPlace) }
                }
            )) {
                addPlaceSheet
            }
            .sheet(isPresented: Binding(
                get: { store.showSurpriseMe },
                set: { newValue in
                    if !newValue { store.send(.dismissSurpriseMe) }
                }
            )) {
                surpriseMeSheet
            }
            .navigationDestination(isPresented: Binding(
                get: { store.selectedPlaceId != nil },
                set: { if !$0 { store.send(.selectPlace(nil)) } }
            )) {
                if let id = store.selectedPlaceId, let place = store.places.first(where: { $0.id == id }) {
                    PlaceDetailView(store: store, place: place)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    // MARK: - Location Bar

    private var locationBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(store.isUsingCustomLocation ? .orange : .blue)

            if store.locationDisplayName.isEmpty {
                Text("Searching location...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(store.locationDisplayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // City search field
            HStack(spacing: 4) {
                TextField("Search city...", text: $store.locationBarText.sending(\.locationBarTextChanged))
                    .font(.caption)
                    .frame(width: 100)
                    .onSubmit {
                        store.send(.locationSearchSubmitted)
                    }

                if store.isSearchingLocation {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            if store.isUsingCustomLocation {
                Button {
                    store.send(.useMyLocation)
                } label: {
                    Image(systemName: "location.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel("Use my location")
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search places...", text: $store.searchText.sending(\.searchTextChanged))
                    .font(.subheadline)
                if !store.searchText.isEmpty {
                    Button {
                        store.send(.searchTextChanged(""))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.top, 8)

            // Search autocomplete results
            if !store.searchResults.isEmpty && !store.searchText.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Discover Nearby")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 6)

                    ForEach(store.searchResults) { result in
                        Button {
                            store.send(.addNearbyPlace(result))
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: categoryIcon(result.category))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(result.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(result.address)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExploreReducer.State.Category.allCases, id: \.self) { category in
                    Button {
                        store.send(.categoryChanged(category))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.caption2)
                            Text(category.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            store.selectedCategory == category
                                ? Color.orange.opacity(0.2)
                                : Color(.systemGray5)
                        )
                        .foregroundStyle(
                            store.selectedCategory == category
                                ? .orange
                                : .secondary
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsRow
                surpriseMeButton

                // Nearby places
                if !store.nearbyResults.isEmpty {
                    nearbySection
                }

                placesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ToolbarContentBuilder
    private var exploreToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Explore")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(.orange)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                store.send(.toggleAddPlace)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Stats Row (Tappable)

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "star.fill",
                title: "Favorites",
                value: "\(store.favoriteCount)",
                subtitle: "saved",
                color: .orange,
                filter: .favorites,
                isActive: store.activeStatFilter == .favorites
            )
            statCard(
                icon: "checkmark.circle.fill",
                title: "Visited",
                value: "\(store.visitedCount)",
                subtitle: "explored",
                color: .green,
                filter: .visited,
                isActive: store.activeStatFilter == .visited
            )
            statCard(
                icon: "list.bullet",
                title: "Bucket List",
                value: "\(store.bucketListCount)",
                subtitle: "to explore",
                color: .blue,
                filter: .bucketList,
                isActive: store.activeStatFilter == .bucketList
            )
        }
    }

    private func statCard(icon: String, title: String, value: String, subtitle: String, color: Color, filter: ExploreReducer.State.StatFilter, isActive: Bool) -> some View {
        Button {
            store.send(.statFilterTapped(filter))
        } label: {
            GlassCard {
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(isActive ? .white : color)
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(isActive ? .white : .primary)
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .background(isActive ? color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Surprise Me

    private var surpriseMeButton: some View {
        Button {
            store.send(.surpriseMeTapped)
        } label: {
            GlassCard {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Surprise Me")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("Discover 3 random nearby spots")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "dice.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var surpriseMeSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.isLoadingSurpriseMe {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.orange)
                            Text("Finding spots near you...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if store.surpriseMeResults.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "mappin.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No results found. Try a different location!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(store.surpriseMeResults) { result in
                            GlassCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: result.categoryIcon)
                                            .foregroundStyle(.orange)
                                        Text(result.name)
                                            .font(.headline)
                                        Spacer()
                                        Text(result.category.capitalized)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.orange.opacity(0.15))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    }

                                    if !result.address.isEmpty {
                                        Text(result.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    HStack(spacing: 8) {
                                        Button {
                                            store.send(.saveSurpriseResult(result))
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "bookmark.fill")
                                                Text("Save")
                                                    .fontWeight(.medium)
                                            }
                                            .font(.caption)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemGray5))
                                            .foregroundStyle(.orange)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }

                                        Button {
                                            openInMaps(address: result.address, name: result.name)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "map.fill")
                                                Text("Directions")
                                                    .fontWeight(.medium)
                                            }
                                            .font(.caption)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.orange.opacity(0.15))
                                            .foregroundStyle(.orange)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Surprise Picks!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { store.send(.dismissSurpriseMe) }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.send(.shuffleSurpriseMe)
                    } label: {
                        Image(systemName: "dice.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Nearby Section

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                Text("Nearby")
                    .font(.headline)
                Spacer()
                if store.isSearchingNearby {
                    ProgressView()
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.nearbyResults) { nearby in
                        Button {
                            store.send(.addNearbyPlace(nearby))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(systemName: categoryIcon(nearby.category))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text(nearby.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(nearby.address)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 140, alignment: .leading)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Places

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.filteredPlaces.isEmpty ? "Recommendations" : "Places")
                    .font(.headline)
                Spacer()
                if let filter = store.activeStatFilter {
                    Button {
                        store.send(.statFilterTapped(filter))
                    } label: {
                        HStack(spacing: 4) {
                            Text(filter.rawValue.capitalized)
                            Image(systemName: "xmark.circle.fill")
                        }
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    }
                }
                Text("\(displayedPlaceCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            if store.filteredPlaces.isEmpty && filteredNearbyRecommendations.isEmpty {
                GlassCard {
                    HStack {
                        Image(systemName: "mappin.slash")
                            .foregroundStyle(.secondary)
                        Text("No recommendations found for this location yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else if store.filteredPlaces.isEmpty {
                ForEach(filteredNearbyRecommendations) { nearby in
                    Button {
                        store.send(.addNearbyPlace(nearby))
                    } label: {
                        recommendationCard(nearby)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(store.filteredPlaces) { place in
                    Button {
                        store.send(.selectPlace(place.id))
                    } label: {
                        placeCard(place)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var displayedPlaceCount: Int {
        store.filteredPlaces.isEmpty ? filteredNearbyRecommendations.count : store.filteredPlaces.count
    }

    private var filteredNearbyRecommendations: [ExploreReducer.State.NearbyPlace] {
        if store.selectedCategory == .all {
            return store.nearbyResults
        }
        return store.nearbyResults.filter { $0.category == store.selectedCategory.filterKey }
    }

    private func recommendationCard(_ nearby: ExploreReducer.State.NearbyPlace) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: categoryIcon(nearby.category))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(nearby.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(nearby.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func placeCard(_ place: ExploreReducer.State.PlaceState) -> some View {
        GlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: place.categoryIcon)
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(place.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if place.isVisited {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        if !place.address.isEmpty {
                            Text(place.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Chevron for drill-down
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if place.rating > 0 {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= place.rating ? "star.fill" : "star")
                                    .font(.system(size: 8))
                                    .foregroundStyle(star <= place.rating ? .orange : .secondary.opacity(0.3))
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "dining": return "fork.knife"
        case "events": return "ticket.fill"
        case "activities": return "figure.hiking"
        case "travel": return "airplane"
        default: return "mappin"
        }
    }

    private func openInMaps(address: String, name: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let query = "\(name) \(trimmed)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        guard let url = URL(string: "http://maps.apple.com/?q=\(query)") else { return }
        guard UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Add Place Sheet

    private var addPlaceSheet: some View {
        NavigationStack {
            Form {
                Section("Place Details") {
                    TextField("Name", text: $store.newPlaceName.sending(\.newPlaceNameChanged))
                    TextField("Address (optional)", text: $store.newPlaceAddress.sending(\.newPlaceAddressChanged))

                    Picker("Category", selection: $store.newPlaceCategory.sending(\.newPlaceCategoryChanged)) {
                        Label("Dining", systemImage: "fork.knife").tag("dining")
                        Label("Events", systemImage: "ticket.fill").tag("events")
                        Label("Activities", systemImage: "figure.hiking").tag("activities")
                        Label("Travel", systemImage: "airplane").tag("travel")
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $store.newPlaceNotes.sending(\.newPlaceNotesChanged), axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissAddPlace) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { store.send(.addPlace) }
                        .fontWeight(.semibold)
                        .disabled(store.newPlaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
