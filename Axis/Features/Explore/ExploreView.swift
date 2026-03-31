import ComposableArchitecture
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ExploreView: View {
    @Bindable var store: StoreOf<ExploreReducer>
    @State private var selectedNearby: ExploreReducer.State.NearbyPlace?
    @State private var placeDescription = ""
    @State private var isLoadingDescription = false

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
            .sheet(item: $selectedNearby) { place in
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Header
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: categoryIcon(place.category))
                                        .font(.title2)
                                        .foregroundStyle(.orange)
                                    Text(place.name)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                }
                                HStack(spacing: 8) {
                                    Text(place.category.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.orange.opacity(0.15))
                                        .foregroundStyle(.orange)
                                        .clipShape(.capsule)
                                    if place.isVerified {
                                        HStack(spacing: 2) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                            Text("Verified")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                            }

                            // Yelp Rating
                            if place.rating > 0 {
                                HStack(spacing: 6) {
                                    HStack(spacing: 2) {
                                        ForEach(1...5, id: \.self) { star in
                                            Image(systemName: Double(star) <= place.rating ? "star.fill" : (Double(star) - 0.5 <= place.rating ? "star.leadinghalf.filled" : "star"))
                                                .font(.caption)
                                                .foregroundStyle(Double(star) <= place.rating ? .orange : .gray.opacity(0.3))
                                        }
                                    }
                                    Text(String(format: "%.1f", place.rating))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.orange)
                                    Text("(\(place.reviewCount) reviews)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !place.price.isEmpty {
                                        Text(place.price)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }

                            // Hours
                            if !place.todayHours.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(.green)
                                    VStack(alignment: .leading) {
                                        Text("Today's Hours")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(place.todayHours)
                                            .font(.subheadline)
                                    }
                                }
                            }

                            // Address
                            if !place.address.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(place.address)
                                        .font(.subheadline)
                                }
                            }

                            // Phone
                            if !place.phoneNumber.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "phone.circle.fill")
                                        .foregroundStyle(.green)
                                    Link(place.phoneNumber, destination: URL(string: "tel:\(place.phoneNumber.filter(\.isNumber))")!)
                                        .font(.subheadline)
                                }
                            }

                            // Website
                            if !place.websiteURL.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .foregroundStyle(.blue)
                                    Link("Visit Website", destination: URL(string: place.websiteURL)!)
                                        .font(.subheadline)
                                }
                            }

                            // Yelp Link
                            if !place.yelpURL.isEmpty, let url = URL(string: place.yelpURL) {
                                HStack(spacing: 8) {
                                    Image(systemName: "star.circle.fill")
                                        .foregroundStyle(.red)
                                    Link("View on Yelp", destination: url)
                                        .font(.subheadline)
                                }
                            }

                            // Google Search fallback if no website
                            if place.websiteURL.isEmpty && place.yelpURL.isEmpty {
                                let query = "\(place.name) \(place.address)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.blue)
                                    Link("Search on Google", destination: URL(string: "https://www.google.com/search?q=\(query)")!)
                                        .font(.subheadline)
                                }
                            }

                            // AI Description
                            if isLoadingDescription {
                                HStack {
                                    ProgressView().scaleEffect(0.7)
                                    Text("Loading description...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if !placeDescription.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("About")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.axisGold)
                                    Text(placeDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()

                            // Actions
                            VStack(spacing: 12) {
                                Button {
                                    store.send(.addNearbyPlace(place))
                                    selectedNearby = nil
                                } label: {
                                    Label("Save to My Places", systemImage: "star.circle.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundStyle(.orange)
                                        .clipShape(.rect(cornerRadius: 12))
                                }

                                if !place.address.isEmpty {
                                    Button {
                                        let query = place.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                        if let url = URL(string: "maps://?q=\(query)") {
                                            PlatformServices.openURL(url)
                                        }
                                    } label: {
                                        Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundStyle(.blue)
                                            .clipShape(.rect(cornerRadius: 12))
                                    }

                                    Button {
                                        let body = "\(place.name)\n\(place.address)\n\nSent from AXIS"
                                        let encodedSubject = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                        #if os(iOS)
                                        let outlookURL = "ms-outlook://compose?subject=\(encodedSubject)&body=\(encodedBody)"
                                        if let url = URL(string: outlookURL), UIApplication.shared.canOpenURL(url) {
                                            PlatformServices.openURL(url)
                                        } else {
                                            let mailtoURL = "mailto:?subject=\(encodedSubject)&body=\(encodedBody)"
                                            if let url = URL(string: mailtoURL) {
                                                PlatformServices.openURL(url)
                                            }
                                        }
                                        #else
                                        let mailtoURL = "mailto:?subject=\(encodedSubject)&body=\(encodedBody)"
                                        if let url = URL(string: mailtoURL) {
                                            PlatformServices.openURL(url)
                                        }
                                        #endif
                                    } label: {
                                        Label("Email Location", systemImage: "envelope.fill")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(Color.purple.opacity(0.15))
                                            .foregroundStyle(.purple)
                                            .clipShape(.rect(cornerRadius: 12))
                                    }

                                    if place.category == "dining" || place.category == "coffee" {
                                        Button {
                                            let encoded = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                            #if os(iOS)
                                            if let ue = URL(string: "ubereats://search?q=\(encoded)"), UIApplication.shared.canOpenURL(ue) {
                                                PlatformServices.openURL(ue)
                                            } else if let dd = URL(string: "doordash://search?query=\(encoded)"), UIApplication.shared.canOpenURL(dd) {
                                                PlatformServices.openURL(dd)
                                            } else if let web = URL(string: "https://www.ubereats.com/search?q=\(encoded)") {
                                                PlatformServices.openURL(web)
                                            }
                                            #else
                                            if let web = URL(string: "https://www.ubereats.com/search?q=\(encoded)") {
                                                PlatformServices.openURL(web)
                                            }
                                            #endif
                                        } label: {
                                            Label("Order Food", systemImage: "bag.fill")
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.green.opacity(0.15))
                                                .foregroundStyle(.green)
                                                .clipShape(.rect(cornerRadius: 12))
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .task(id: selectedNearby?.id) {
                        guard let place = selectedNearby else { return }
                        isLoadingDescription = true
                        placeDescription = ""
                        let key = MultiProviderChatService.shared.anthropicAPIKey
                        guard !key.isEmpty else { isLoadingDescription = false; return }
                        let url = URL(string: "https://api.anthropic.com/v1/messages")!
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.setValue(key, forHTTPHeaderField: "x-api-key")
                        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                        request.timeoutInterval = 8
                        let body: [String: Any] = [
                            "model": "claude-sonnet-4-20250514",
                            "max_tokens": 80,
                            "messages": [["role": "user", "content": "In 1-2 sentences, describe this place: \(place.name) at \(place.address). Category: \(place.category). Be factual and concise."]]
                        ]
                        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                        do {
                            let (data, _) = try await URLSession.shared.data(for: request)
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let content = json["content"] as? [[String: Any]],
                               let text = content.first?["text"] as? String {
                                placeDescription = text
                            }
                        } catch {}
                        isLoadingDescription = false
                    }
                    .navigationTitle("Place Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selectedNearby = nil }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(24)
                .presentationBackground(.ultraThinMaterial)
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
                TextField("Search a city, address, or business...", text: $store.locationBarText.sending(\.locationBarTextChanged))
                    .font(.body)
                    .textContentType(.fullStreetAddress)
                    .autocorrectionDisabled(false)
                    .frame(width: 180)
                    .onSubmit {
                        store.send(.locationSearchSubmitted)
                    }

                if store.isSearchingLocation {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
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
                            store.send(.viewedPlace(result))
                            selectedNearby = result
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
                                    if !result.todayHours.isEmpty {
                                        HStack(spacing: 2) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 8))
                                                .foregroundStyle(.green)
                                            Text(result.todayHours)
                                                .font(.system(size: 8))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            store.selectedCategory == category
                                ? Color.orange
                                : Color(.secondarySystemGroupedBackground)
                        )
                        .foregroundStyle(
                            store.selectedCategory == category
                                ? .white
                                : .primary
                        )
                        .clipShape(Capsule())
                        .shadow(color: store.selectedCategory == category ? .orange.opacity(0.3) : .clear, radius: 4, y: 2)
                        .scaleEffect(store.selectedCategory == category ? 1.05 : 1.0)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.selectedCategory)
        }
    }

    private var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsRow
                surpriseMeButton
                nearMeNowButton

                // Nearby places
                if !store.nearbyResults.isEmpty {
                    nearbySection
                }

                // Recently Viewed
                if !store.recentlyViewed.isEmpty {
                    recentlyViewedSection
                }

                placesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.immediately)
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
                        .contentTransition(.numericText())
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
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Near Me Now

    private var nearMeNowButton: some View {
        Button {
            store.send(.useMyLocation)
            store.send(.searchNearby)
        } label: {
            GlassCard {
                HStack {
                    Image(systemName: "location.viewfinder")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Near Me Now")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("Find places at your current GPS location")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
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
                                        HStack(spacing: 4) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundStyle(.red)
                                                .font(.caption)
                                            Text(result.address)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    if !result.phoneNumber.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "phone.circle.fill")
                                                .foregroundStyle(.green)
                                                .font(.caption)
                                            Link(result.phoneNumber, destination: URL(string: "tel:\(result.phoneNumber.filter(\.isNumber))")!)
                                                .font(.caption)
                                        }
                                    }

                                    if !result.websiteURL.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "globe")
                                                .foregroundStyle(.blue)
                                                .font(.caption)
                                            Link("Visit Website", destination: URL(string: result.websiteURL)!)
                                                .font(.caption)
                                        }
                                    }

                                    // Rating + Hours + Price
                                    if result.rating > 0 {
                                        HStack(spacing: 4) {
                                            ForEach(1...5, id: \.self) { star in
                                                Image(systemName: Double(star) <= result.rating ? "star.fill" : "star")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Double(star) <= result.rating ? .orange : .gray.opacity(0.3))
                                            }
                                            Text("\(result.rating, specifier: "%.1f") (\(result.reviewCount))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            if !result.price.isEmpty {
                                                Text("• \(result.price)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                    }

                                    if !result.todayHours.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                            Text(result.todayHours)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    if result.isVerified {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundStyle(.green)
                                                .font(.caption2)
                                            Text("Verified")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                        }
                                    }

                                    HStack(spacing: 6) {
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

                                        if result.category == "dining" || result.category == "coffee" {
                                            Button {
                                                let encoded = result.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                                #if os(iOS)
                                                if let ue = URL(string: "ubereats://search?q=\(encoded)"), UIApplication.shared.canOpenURL(ue) {
                                                    PlatformServices.openURL(ue)
                                                } else if let dd = URL(string: "doordash://search?query=\(encoded)"), UIApplication.shared.canOpenURL(dd) {
                                                    PlatformServices.openURL(dd)
                                                } else if let web = URL(string: "https://www.ubereats.com/search?q=\(encoded)") {
                                                    PlatformServices.openURL(web)
                                                }
                                                #else
                                                if let web = URL(string: "https://www.ubereats.com/search?q=\(encoded)") {
                                                    PlatformServices.openURL(web)
                                                }
                                                #endif
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "bag.fill")
                                                    Text("Order")
                                                        .fontWeight(.medium)
                                                }
                                                .font(.caption)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(Color.green.opacity(0.15))
                                                .foregroundStyle(.green)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
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
        .presentationCornerRadius(24)
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Nearby Section

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(Color.axisGold)
                Text("Nearby")
                    .font(.headline)
                Spacer()
                Text("\(store.nearbyResults.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            if store.isSearchingNearby {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 140, height: 100)
                                .shimmer()
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.nearbyResults) { nearby in
                        Button {
                            store.send(.viewedPlace(nearby))
                            selectedNearby = nearby
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
                                if nearby.isVerified {
                                    HStack(spacing: 2) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                        Text("Verified")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    }
                                }
                                if nearby.rating > 0 {
                                    HStack(spacing: 2) {
                                        ForEach(1...5, id: \.self) { star in
                                            Image(systemName: Double(star) <= nearby.rating ? "star.fill" : (Double(star) - 0.5 <= nearby.rating ? "star.leadinghalf.filled" : "star"))
                                                .font(.system(size: 8))
                                                .foregroundStyle(Double(star) <= nearby.rating ? .orange : .gray.opacity(0.3))
                                        }
                                        Text("(\(nearby.reviewCount))")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if !nearby.todayHours.isEmpty {
                                    HStack(spacing: 2) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.green)
                                        Text(nearby.todayHours)
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if !nearby.price.isEmpty {
                                    Text(nearby.price)
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                            }
                            .frame(width: 140, alignment: .leading)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    // Load More button
                    if !store.nearbyResults.isEmpty {
                        Button {
                            store.send(.loadMoreNearby)
                        } label: {
                            if store.isLoadingMore {
                                ProgressView()
                                    .frame(width: 100, height: 60)
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.orange)
                                    Text("Load More")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                .frame(width: 100, height: 60)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .scrollTargetLayout()
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .animation(.easeInOut(duration: 0.3), value: store.nearbyResults.count)
    }

    // MARK: - Recently Viewed

    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Color.axisGold)
                Text("Recently Viewed")
                    .font(.headline)
                Spacer()
                Text("\(store.recentlyViewed.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            ForEach(store.recentlyViewed) { place in
                Button {
                    selectedNearby = place
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: categoryIcon(place.category))
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(place.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text(place.address)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if !place.todayHours.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.green)
                                    Text(place.todayHours)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        if place.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Places

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: store.filteredPlaces.isEmpty ? "sparkles" : "mappin.and.ellipse")
                    .foregroundStyle(Color.axisGold)
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
                        store.send(.viewedPlace(nearby))
                        selectedNearby = nearby
                    } label: {
                        recommendationCard(nearby)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            } else {
                ForEach(store.filteredPlaces) { place in
                    Button {
                        store.send(.selectPlace(place.id))
                    } label: {
                        placeCard(place)
                    }
                    .buttonStyle(ScaleButtonStyle())
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: categoryIcon(nearby.category))
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(nearby.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            if nearby.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        Text(nearby.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.orange)
                }

                // Rating + Hours + Price
                HStack(spacing: 12) {
                    if nearby.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: Double(star) <= nearby.rating ? "star.fill" : "star")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Double(star) <= nearby.rating ? .orange : .gray.opacity(0.3))
                            }
                            Text("\(nearby.reviewCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !nearby.price.isEmpty {
                        Text(nearby.price)
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                if !nearby.todayHours.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(nearby.todayHours)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
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

                    // Star ratings
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= place.rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(star <= place.rating ? .orange : .gray.opacity(0.3))
                        }
                    }

                    // Chevron for drill-down
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        case "blackOwned": return "hand.raised.fill"
        case "kids": return "figure.and.child.holdinghands"
        default: return "mappin"
        }
    }

    private func openInMaps(address: String, name: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let query = "\(name) \(trimmed)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        guard let url = URL(string: "http://maps.apple.com/?q=\(query)") else { return }
        PlatformServices.openURL(url)
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
                        Label("Black-Owned", systemImage: "hand.raised.fill").tag("blackOwned")
                        Label("Kids", systemImage: "figure.and.child.holdinghands").tag("kids")
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

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ExploreView(
        store: Store(initialState: ExploreReducer.State()) {
            ExploreReducer()
        }
    )
}
