import ComposableArchitecture
import SwiftUI
import UIKit

struct ExploreView: View {
    @Bindable var store: StoreOf<ExploreReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                categoryChips
                mainScrollView
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { exploreToolbar }
            .sheet(isPresented: Binding(
                get: { store.showAddPlace },
                set: { _ in store.send(.toggleAddPlace) }
            )) {
                addPlaceSheet
            }
            .alert("Surprise Pick!", isPresented: Binding(
                get: { store.showSurpriseMe },
                set: { _ in store.send(.dismissSurpriseMe) }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                if let place = store.surpriseMePlace {
                    Text("How about \(place.name)?\n\(place.notes)")
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search places...", text: $store.searchText.sending(\.searchTextChanged))
                .font(.subheadline)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
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
                placesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
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

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            WidgetCardView(
                icon: "star.fill",
                title: "Favorites",
                value: "\(store.favoriteCount)",
                subtitle: "saved",
                color: .orange
            )
            WidgetCardView(
                icon: "checkmark.circle.fill",
                title: "Visited",
                value: "\(store.visitedCount)",
                subtitle: "explored",
                color: .green
            )
            WidgetCardView(
                icon: "list.bullet",
                title: "Bucket List",
                value: "\(store.bucketListCount)",
                subtitle: "to explore",
                color: .blue
            )
        }
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
                        Text("Pick a random unvisited spot")
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

    // MARK: - Places

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Places")
                    .font(.headline)
                Spacer()
                Text("\(store.filteredPlaces.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            if store.filteredPlaces.isEmpty {
                GlassCard {
                    HStack {
                        Image(systemName: "mappin.slash")
                            .foregroundStyle(.secondary)
                        Text("No places found. Add some spots to explore!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(store.filteredPlaces) { place in
                    placeCard(place)
                }
            }
        }
    }

    private func placeCard(_ place: ExploreReducer.State.PlaceState) -> some View {
        GlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    // Category icon
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

                    // Star rating
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

                if !place.notes.isEmpty {
                    Text(place.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(2)
                }

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        openInMaps(address: place.address, name: place.name)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .font(.caption2)
                            Text("Directions")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .foregroundStyle(place.address.isEmpty ? Color.secondary.opacity(0.5) : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(place.address.isEmpty)

                    Button {
                        store.send(.toggleFavorite(place.id))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: place.isFavorite ? "heart.fill" : "heart")
                                .font(.caption2)
                            Text(place.isFavorite ? "Saved" : "Save")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(place.isFavorite ? Color.orange.opacity(0.1) : Color(.systemGray5))
                        .foregroundStyle(place.isFavorite ? .orange : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        store.send(.toggleVisited(place.id))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: place.isVisited ? "checkmark.circle.fill" : "circle")
                                .font(.caption2)
                            Text(place.isVisited ? "Visited" : "Mark Visited")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(place.isVisited ? Color.green.opacity(0.1) : Color(.systemGray5))
                        .foregroundStyle(place.isVisited ? .green : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        store.send(.deletePlace(place.id))
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func openInMaps(address: String, name: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let query = "\(name) \(trimmed)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        guard let url = URL(string: "http://maps.apple.com/?q=\(query)") else { return }
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
                    Button("Cancel") { store.send(.toggleAddPlace) }
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
