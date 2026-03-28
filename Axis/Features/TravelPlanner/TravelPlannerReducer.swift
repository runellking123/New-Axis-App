import ComposableArchitecture
import Foundation

@Reducer
struct TravelPlannerReducer {
    @ObservableState
    struct State: Equatable {
        var trips: [TripItem] = []
        var selectedTrip: TripItem? = nil
        var itineraryDays: [DayItem] = []
        var showAddTrip: Bool = false
        var showAddDay: Bool = false
        var selectedSection: Section = .upcoming

        // Add trip form
        var formName: String = ""
        var formDestination: String = ""
        var formStartDate: Date = Date()
        var formEndDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        var formBudget: String = ""
        var formNotes: String = ""

        // Add day form
        var dayFormNotes: String = ""
        var dayFormActivities: String = ""

        // Packing list
        var packingItems: [PackingItem] = []
        var newPackingItemText: String = ""

        enum Section: String, CaseIterable {
            case upcoming = "Upcoming"
            case past = "Past"
        }

        struct TripItem: Equatable, Identifiable {
            let id: UUID
            var name: String
            var startDate: Date
            var endDate: Date
            var budgetPlanned: Double
            var budgetSpent: Double
            var notes: String
            var createdAt: Date

            var daysUntil: Int {
                Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
            }
            var duration: Int {
                max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
            }
            var isActive: Bool {
                let today = Date()
                return today >= startDate && today <= endDate
            }
            var isPast: Bool {
                Date() > endDate
            }
            var budgetRemaining: Double {
                budgetPlanned - budgetSpent
            }
        }

        struct DayItem: Equatable, Identifiable {
            let id: UUID
            var dayNumber: Int
            var date: Date
            var notes: String
            var activities: String
        }

        struct PackingItem: Equatable, Identifiable {
            let id: UUID
            var name: String
            var isPacked: Bool
        }

        var filteredTrips: [TripItem] {
            switch selectedSection {
            case .upcoming:
                return trips.filter { !$0.isPast }.sorted { $0.startDate < $1.startDate }
            case .past:
                return trips.filter { $0.isPast }.sorted { $0.startDate > $1.startDate }
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case tripsLoaded([State.TripItem])
        case sectionChanged(State.Section)
        case showAddTrip
        case dismissAddTrip
        case formNameChanged(String)
        case formDestinationChanged(String)
        case formStartDateChanged(Date)
        case formEndDateChanged(Date)
        case formBudgetChanged(String)
        case formNotesChanged(String)
        case saveTrip
        case selectTrip(State.TripItem?)
        case deleteTrip(State.TripItem)
        case itineraryLoaded([State.DayItem])
        case showAddDay
        case dismissAddDay
        case dayFormNotesChanged(String)
        case dayFormActivitiesChanged(String)
        case saveDay
        case deleteDay(State.DayItem)
        case updateBudgetSpent(Double)
        // Packing
        case newPackingItemTextChanged(String)
        case addPackingItem
        case togglePackingItem(State.PackingItem)
        case deletePackingItem(State.PackingItem)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let fetched = PersistenceService.shared.fetchTrips()
                    let items = fetched.map { t in
                        State.TripItem(id: t.uuid, name: t.name, startDate: t.startDate, endDate: t.endDate, budgetPlanned: t.budgetPlanned, budgetSpent: t.budgetSpent, notes: t.notes, createdAt: t.createdAt)
                    }
                    await send(.tripsLoaded(items))
                }

            case let .tripsLoaded(items):
                state.trips = items
                return .none

            case let .sectionChanged(section):
                state.selectedSection = section
                return .none

            case .showAddTrip:
                state.formName = ""
                state.formDestination = ""
                state.formStartDate = Date()
                state.formEndDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
                state.formBudget = ""
                state.formNotes = ""
                state.showAddTrip = true
                return .none

            case .dismissAddTrip:
                state.showAddTrip = false
                return .none

            case let .formNameChanged(t): state.formName = t; return .none
            case let .formDestinationChanged(t): state.formNotes = t; return .none
            case let .formStartDateChanged(d): state.formStartDate = d; return .none
            case let .formEndDateChanged(d): state.formEndDate = d; return .none
            case let .formBudgetChanged(t): state.formBudget = t; return .none
            case let .formNotesChanged(t): state.formNotes = t; return .none

            case .saveTrip:
                let name = state.formName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    state.showAddTrip = false
                    return .none
                }
                let trip = Trip(
                    name: name,
                    startDate: state.formStartDate,
                    endDate: state.formEndDate,
                    budgetPlanned: Double(state.formBudget) ?? 0,
                    notes: state.formNotes
                )
                PersistenceService.shared.saveTrip(trip)
                state.showAddTrip = false
                return .send(.onAppear)

            case let .selectTrip(trip):
                state.selectedTrip = trip
                state.packingItems = loadPackingItems(for: trip?.id)
                if let trip {
                    return .run { send in
                        let days = PersistenceService.shared.fetchItineraryDays(forTrip: trip.id)
                        let items = days.map { d in
                            State.DayItem(id: d.uuid, dayNumber: d.dayNumber, date: d.date, notes: d.notes, activities: d.placeIds.isEmpty ? "" : "")
                        }
                        await send(.itineraryLoaded(items))
                    }
                }
                state.itineraryDays = []
                return .none

            case let .deleteTrip(trip):
                let trips = PersistenceService.shared.fetchTrips()
                if let match = trips.first(where: { $0.uuid == trip.id }) {
                    PersistenceService.shared.deleteTrip(match)
                }
                clearPackingItems(for: trip.id)
                if state.selectedTrip?.id == trip.id {
                    state.selectedTrip = nil
                }
                return .send(.onAppear)

            case let .itineraryLoaded(days):
                state.itineraryDays = days
                return .none

            case .showAddDay:
                state.dayFormNotes = ""
                state.dayFormActivities = ""
                state.showAddDay = true
                return .none

            case .dismissAddDay:
                state.showAddDay = false
                return .none

            case let .dayFormNotesChanged(t): state.dayFormNotes = t; return .none
            case let .dayFormActivitiesChanged(t): state.dayFormActivities = t; return .none

            case .saveDay:
                guard let trip = state.selectedTrip else {
                    state.showAddDay = false
                    return .none
                }
                let dayNum = state.itineraryDays.count + 1
                let date = Calendar.current.date(byAdding: .day, value: dayNum - 1, to: trip.startDate) ?? Date()
                let day = ItineraryDay(tripId: trip.id, dayNumber: dayNum, date: date, notes: state.dayFormNotes)
                PersistenceService.shared.saveItineraryDay(day)
                state.showAddDay = false
                return .send(.selectTrip(trip))

            case let .deleteDay(day):
                let days = PersistenceService.shared.fetchItineraryDays(forTrip: state.selectedTrip?.id ?? UUID())
                if let match = days.first(where: { $0.uuid == day.id }) {
                    PersistenceService.shared.deleteItineraryDay(match)
                }
                if let trip = state.selectedTrip {
                    return .send(.selectTrip(trip))
                }
                return .none

            case let .updateBudgetSpent(amount):
                guard let trip = state.selectedTrip else { return .none }
                let trips = PersistenceService.shared.fetchTrips()
                if let match = trips.first(where: { $0.uuid == trip.id }) {
                    match.budgetSpent = amount
                    PersistenceService.shared.updateTrips()
                }
                state.selectedTrip?.budgetSpent = amount
                return .none

            // Packing list (stored in UserDefaults per trip)
            case let .newPackingItemTextChanged(t):
                state.newPackingItemText = t
                return .none

            case .addPackingItem:
                let text = state.newPackingItemText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, let tripId = state.selectedTrip?.id else { return .none }
                let item = State.PackingItem(id: UUID(), name: text, isPacked: false)
                state.packingItems.append(item)
                state.newPackingItemText = ""
                savePackingItems(state.packingItems, for: tripId)
                return .none

            case let .togglePackingItem(item):
                if let idx = state.packingItems.firstIndex(where: { $0.id == item.id }) {
                    state.packingItems[idx].isPacked.toggle()
                    if let tripId = state.selectedTrip?.id {
                        savePackingItems(state.packingItems, for: tripId)
                    }
                }
                return .none

            case let .deletePackingItem(item):
                state.packingItems.removeAll { $0.id == item.id }
                if let tripId = state.selectedTrip?.id {
                    savePackingItems(state.packingItems, for: tripId)
                }
                return .none
            }
        }
    }

    // Packing list persistence via UserDefaults
    private func loadPackingItems(for tripId: UUID?) -> [State.PackingItem] {
        guard let tripId else { return [] }
        guard let data = UserDefaults.standard.data(forKey: "packing_\(tripId.uuidString)"),
              let decoded = try? JSONDecoder().decode([PackingItemCodable].self, from: data) else { return [] }
        return decoded.map { State.PackingItem(id: $0.id, name: $0.name, isPacked: $0.isPacked) }
    }

    private func savePackingItems(_ items: [State.PackingItem], for tripId: UUID) {
        let codable = items.map { PackingItemCodable(id: $0.id, name: $0.name, isPacked: $0.isPacked) }
        if let data = try? JSONEncoder().encode(codable) {
            UserDefaults.standard.set(data, forKey: "packing_\(tripId.uuidString)")
        }
    }

    private func clearPackingItems(for tripId: UUID) {
        UserDefaults.standard.removeObject(forKey: "packing_\(tripId.uuidString)")
    }
}

private struct PackingItemCodable: Codable {
    let id: UUID
    let name: String
    let isPacked: Bool
}
