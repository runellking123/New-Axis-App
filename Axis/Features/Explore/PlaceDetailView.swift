import ComposableArchitecture
import MapKit
import SwiftUI

struct PlaceDetailView: View {
    @Bindable var store: StoreOf<ExploreReducer>
    let place: ExploreReducer.State.PlaceState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Map snippet
                if !place.address.isEmpty {
                    mapSection
                }

                // Info card
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: place.categoryIcon)
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                if !place.address.isEmpty {
                                    Text(place.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }

                // Rating
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rating")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    store.send(.updatePlaceRating(place.id, star))
                                } label: {
                                    Image(systemName: star <= place.rating ? "star.fill" : "star")
                                        .font(.title2)
                                        .foregroundStyle(star <= place.rating ? .orange : .secondary.opacity(0.3))
                                }
                            }
                            Spacer()
                        }
                    }
                }

                // Category
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            categoryChip("dining", icon: "fork.knife", label: "Dining")
                            categoryChip("events", icon: "ticket.fill", label: "Events")
                            categoryChip("activities", icon: "figure.hiking", label: "Activities")
                            categoryChip("travel", icon: "airplane", label: "Travel")
                        }
                    }
                }

                // Toggles
                GlassCard {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: place.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(place.isFavorite ? .orange : .secondary)
                            Text("Favorite")
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { place.isFavorite },
                                set: { _ in store.send(.toggleFavorite(place.id)) }
                            ))
                            .tint(.orange)
                        }

                        Divider()

                        HStack {
                            Image(systemName: place.isVisited ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(place.isVisited ? .green : .secondary)
                            Text("Visited")
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { place.isVisited },
                                set: { _ in store.send(.toggleVisited(place.id)) }
                            ))
                            .tint(.green)
                        }
                    }
                }

                // Notes
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Add notes...", text: Binding(
                            get: { place.notes },
                            set: { store.send(.updatePlaceNotes(place.id, $0)) }
                        ), axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(3...8)
                    }
                }

                // Directions button
                if !place.address.isEmpty {
                    Button {
                        openInMaps()
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Get Directions")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Delete
                Button(role: .destructive) {
                    store.send(.deletePlace(place.id))
                    store.send(.selectPlace(nil))
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Place")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mapSection: some View {
        Map {
            // Empty map centered on address
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
    }

    private func categoryChip(_ key: String, icon: String, label: String) -> some View {
        Button {
            store.send(.updatePlaceCategory(place.id, key))
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(place.category == key ? Color.orange.opacity(0.2) : Color(.systemGray5))
            .foregroundStyle(place.category == key ? .orange : .secondary)
            .clipShape(Capsule())
        }
    }

    private func openInMaps() {
        let query = "\(place.name) \(place.address)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.address
        guard let url = URL(string: "http://maps.apple.com/?q=\(query)") else { return }
        UIApplication.shared.open(url)
    }
}
