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

                // Category-specific details
                categoryDetailSection

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

                // Email Location
                Button {
                    let body = "\(place.name)\n\(place.address)\n\nSent from AXIS"
                    let encodedSubject = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let outlookURL = "ms-outlook://compose?subject=\(encodedSubject)&body=\(encodedBody)"
                    if let url = URL(string: outlookURL), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        let mailtoURL = "mailto:?subject=\(encodedSubject)&body=\(encodedBody)"
                        if let url = URL(string: mailtoURL) {
                            UIApplication.shared.open(url)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Email Location")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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

    @ViewBuilder
    private var categoryDetailSection: some View {
        switch place.category {
        case "dining":
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Contact & Hours")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !place.phoneNumber.isEmpty {
                        phoneRow
                    }
                    if !place.websiteURL.isEmpty {
                        websiteRow
                    }
                    hoursRow
                }
            }
        case "events":
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Event Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "text.alignleft")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        TextField("Add event details...", text: Binding(
                            get: { place.placeDescription },
                            set: { store.send(.updatePlaceDescription(place.id, $0)) }
                        ), axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(3...8)
                    }
                    if !place.websiteURL.isEmpty {
                        websiteRow
                    }
                }
            }
        case "activities":
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hours & Info")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !place.phoneNumber.isEmpty {
                        phoneRow
                    }
                    hoursRow
                    if !place.websiteURL.isEmpty {
                        websiteRow
                    }
                }
            }
        case "travel":
            if !place.phoneNumber.isEmpty || !place.websiteURL.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if !place.phoneNumber.isEmpty {
                            phoneRow
                        }
                        if !place.websiteURL.isEmpty {
                            websiteRow
                        }
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    private var phoneRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "phone.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .frame(width: 20)
            Text(place.phoneNumber)
                .font(.subheadline)
            Spacer()
            if let url = URL(string: "tel:\(place.phoneNumber.replacingOccurrences(of: " ", with: ""))") {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Image(systemName: "phone.arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(6)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
    }

    private var websiteRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .frame(width: 20)
            Text(place.websiteURL)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if let url = URL(string: place.websiteURL) {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(6)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
    }

    private var hoursRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .frame(width: 20)
            TextField("Add hours...", text: Binding(
                get: { place.hoursOfOperation },
                set: { store.send(.updatePlaceHours(place.id, $0)) }
            ), axis: .vertical)
            .font(.subheadline)
            .lineLimit(1...3)
        }
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
        guard UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    PlaceDetailView(
        store: Store(initialState: ExploreReducer.State()) {
            ExploreReducer()
        },
        place: ExploreReducer.State.PlaceState(
            id: UUID(),
            name: "Coffee Shop",
            category: "cafe",
            address: "123 Main St",
            notes: "Great espresso",
            rating: 4,
            isVisited: true,
            isFavorite: false
        )
    )
}
