import SwiftUI
import ComposableArchitecture

struct TravelPlannerView: View {
    @Bindable var store: StoreOf<TravelPlannerReducer>
    @State private var mainTab = 0  // 0 = My Trips, 1 = Find Agents

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main tab switcher
                Picker("View", selection: $mainTab) {
                    Text("My Trips").tag(0)
                    Text("Find Agents").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if mainTab == 1 {
                    TravelAgentsView()
                } else {
                    // Trip section filter
                    Picker("Section", selection: $store.selectedSection.sending(\.sectionChanged)) {
                        ForEach(TravelPlannerReducer.State.Section.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 4)

                    if store.filteredTrips.isEmpty {
                        emptyState
                    } else {
                        tripsList
                    }
                }
            }
            .navigationTitle("Travel")
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { store.send(.showAddTrip) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.axisGold)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddTrip },
                set: { if !$0 { store.send(.dismissAddTrip) } }
            )) {
                AddTripSheet(store: store)
            }
            .sheet(item: Binding(
                get: { store.selectedTrip },
                set: { store.send(.selectTrip($0)) }
            )) { trip in
                TripDetailSheet(store: store, trip: trip)
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "airplane.departure")
                .font(.system(size: 60))
                .foregroundStyle(Color.axisGold.opacity(0.5))
            Text(store.selectedSection == .upcoming ? "No Upcoming Trips" : "No Past Trips")
                .font(.title2.bold())
            Text("Tap + to plan your next adventure")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var tripsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.filteredTrips) { trip in
                    tripCard(trip)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private func tripCard(_ trip: TravelPlannerReducer.State.TripItem) -> some View {
        Button { store.send(.selectTrip(trip)) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.name)
                            .font(.headline)
                        Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) - \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if trip.isActive {
                        Text("NOW")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    } else if !trip.isPast {
                        Text("\(trip.daysUntil)d")
                            .font(.caption.bold())
                            .foregroundStyle(Color.axisGold)
                    }
                }

                HStack(spacing: 16) {
                    Label("\(trip.duration) days", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if trip.budgetPlanned > 0 {
                        Label("$\(Int(trip.budgetPlanned))", systemImage: "dollarsign.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                store.send(.deleteTrip(trip))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Trip Sheet

struct AddTripSheet: View {
    @Bindable var store: StoreOf<TravelPlannerReducer>

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip Name", text: $store.formName.sending(\.formNameChanged))
                    DatePicker("Start", selection: $store.formStartDate.sending(\.formStartDateChanged), displayedComponents: .date)
                    DatePicker("End", selection: $store.formEndDate.sending(\.formEndDateChanged), displayedComponents: .date)
                }
                Section("Budget") {
                    TextField("Planned Budget ($)", text: $store.formBudget.sending(\.formBudgetChanged))
                        .keyboardType(.decimalPad)
                }
                Section("Notes") {
                    TextEditor(text: $store.formNotes.sending(\.formNotesChanged))
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissAddTrip) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.saveTrip) }
                        .bold()
                        .disabled(store.formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Trip Detail Sheet

struct TripDetailSheet: View {
    @Bindable var store: StoreOf<TravelPlannerReducer>
    let trip: TravelPlannerReducer.State.TripItem
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Trip header
                VStack(spacing: 4) {
                    Text(trip.name)
                        .font(.title2.bold())
                    Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) - \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if trip.budgetPlanned > 0 {
                        HStack(spacing: 16) {
                            Label("Budget: $\(Int(trip.budgetPlanned))", systemImage: "dollarsign.circle")
                            Label("Spent: $\(Int(trip.budgetSpent))", systemImage: "creditcard")
                            Label("Left: $\(Int(trip.budgetRemaining))", systemImage: "arrow.down.circle")
                                .foregroundStyle(trip.budgetRemaining >= 0 ? .green : .red)
                        }
                        .font(.caption)
                        .padding(.top, 4)
                    }
                }
                .padding()

                Picker("Tab", selection: $selectedTab) {
                    Text("Itinerary").tag(0)
                    Text("Packing").tag(1)
                    Text("Notes").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedTab {
                case 0: itineraryTab
                case 1: packingTab
                case 2: notesTab
                default: EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.send(.selectTrip(nil)) }
                }
            }
        }
    }

    private var itineraryTab: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(store.itineraryDays) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Day \(day.dayNumber)")
                                .font(.headline)
                            Spacer()
                            Text(day.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !day.notes.isEmpty {
                            Text(day.notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .contextMenu {
                        Button(role: .destructive) {
                            store.send(.deleteDay(day))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button { store.send(.showAddDay) } label: {
                    Label("Add Day", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.axisGold)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .sheet(isPresented: Binding(
            get: { store.showAddDay },
            set: { if !$0 { store.send(.dismissAddDay) } }
        )) {
            NavigationStack {
                Form {
                    Section("Day \(store.itineraryDays.count + 1)") {
                        TextEditor(text: $store.dayFormNotes.sending(\.dayFormNotesChanged))
                            .frame(minHeight: 100)
                    }
                }
                .navigationTitle("Add Day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { store.send(.dismissAddDay) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { store.send(.saveDay) }.bold()
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var packingTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    TextField("Add item...", text: $store.newPackingItemText.sending(\.newPackingItemTextChanged))
                        .textFieldStyle(.roundedBorder)
                    Button {
                        store.send(.addPackingItem)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.axisGold)
                    }
                    .disabled(store.newPackingItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                let packed = store.packingItems.filter(\.isPacked)
                let unpacked = store.packingItems.filter { !$0.isPacked }

                if !unpacked.isEmpty {
                    ForEach(unpacked) { item in
                        packingRow(item)
                    }
                }

                if !packed.isEmpty {
                    Text("Packed (\(packed.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    ForEach(packed) { item in
                        packingRow(item)
                    }
                }
            }
            .padding()
        }
    }

    private func packingRow(_ item: TravelPlannerReducer.State.PackingItem) -> some View {
        HStack {
            Button { store.send(.togglePackingItem(item)) } label: {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPacked ? Color.green : .secondary)
            }
            Text(item.name)
                .strikethrough(item.isPacked)
                .foregroundStyle(item.isPacked ? .secondary : .primary)
            Spacer()
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.send(.deletePackingItem(item))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var notesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !trip.notes.isEmpty {
                    Text(trip.notes)
                        .font(.body)
                        .padding()
                } else {
                    Text("No notes for this trip")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
    }
}

#Preview {
    TravelPlannerView(
        store: Store(initialState: TravelPlannerReducer.State()) {
            TravelPlannerReducer()
        }
    )
}
