import ComposableArchitecture
import Foundation

@Reducer
struct SocialCircleReducer {
    @ObservableState
    struct State: Equatable {
        var contacts: [ContactState] = []
        var selectedTier: TierFilter = .all
        var showAddContact = false
        var newContactName = ""
        var newContactTier = "closeFriends"
        var newContactPhone = ""
        var newContactRelationship = "friend"
        var newContactCheckInDays = 30
        var searchText = ""

        enum TierFilter: String, CaseIterable, Equatable {
            case all = "All"
            case innerCircle = "Inner Circle"
            case closeFriends = "Close"
            case extended = "Extended"

            var filterKey: String? {
                switch self {
                case .all: return nil
                case .innerCircle: return "innerCircle"
                case .closeFriends: return "closeFriends"
                case .extended: return "extended"
                }
            }
        }

        struct ContactState: Equatable, Identifiable {
            let id: UUID
            var name: String
            var tier: String
            var phone: String
            var relationship: String
            var lastContacted: Date?
            var checkInDays: Int
            var birthday: Date?

            var tierLabel: String {
                switch tier {
                case "innerCircle": return "Inner Circle"
                case "closeFriends": return "Close Friends"
                case "extended": return "Extended"
                default: return tier
                }
            }

            var tierIcon: String {
                switch tier {
                case "innerCircle": return "star.circle.fill"
                case "closeFriends": return "heart.circle.fill"
                case "extended": return "person.circle.fill"
                default: return "person.circle"
                }
            }

            var tierColor: String {
                switch tier {
                case "innerCircle": return "yellow"
                case "closeFriends": return "purple"
                case "extended": return "gray"
                default: return "gray"
                }
            }

            var isOverdue: Bool {
                guard let last = lastContacted else { return true }
                let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
                return daysSince >= checkInDays
            }

            var daysSinceContact: Int {
                guard let last = lastContacted else { return 999 }
                return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            }

            var initials: String {
                let parts = name.split(separator: " ")
                if parts.count >= 2 {
                    return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
                }
                return String(name.prefix(2)).uppercased()
            }

            var daysUntilBirthday: Int? {
                guard let birthday else { return nil }
                let cal = Calendar.current
                let today = Date()
                var components = cal.dateComponents([.month, .day], from: birthday)
                components.year = cal.component(.year, from: today)
                guard var nextBirthday = cal.date(from: components) else { return nil }
                if nextBirthday < today {
                    nextBirthday = cal.date(byAdding: .year, value: 1, to: nextBirthday)!
                }
                return cal.dateComponents([.day], from: today, to: nextBirthday).day
            }
        }

        var filteredContacts: [ContactState] {
            var result = contacts
            if let key = selectedTier.filterKey {
                result = result.filter { $0.tier == key }
            }
            if !searchText.isEmpty {
                result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            return result.sorted { $0.daysSinceContact > $1.daysSinceContact }
        }

        var overdueCount: Int {
            contacts.filter(\.isOverdue).count
        }

        var upcomingBirthdays: [ContactState] {
            contacts
                .filter { $0.daysUntilBirthday != nil && ($0.daysUntilBirthday ?? 999) <= 30 }
                .sorted { ($0.daysUntilBirthday ?? 999) < ($1.daysUntilBirthday ?? 999) }
        }
    }

    enum Action: Equatable {
        case onAppear
        case tierFilterChanged(State.TierFilter)
        case searchTextChanged(String)
        case toggleAddContact
        case newContactNameChanged(String)
        case newContactTierChanged(String)
        case newContactPhoneChanged(String)
        case newContactRelationshipChanged(String)
        case newContactCheckInDaysChanged(Int)
        case addContact
        case deleteContact(UUID)
        case markContacted(UUID)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let persistence = PersistenceService.shared
                let stored = persistence.fetchContacts()
                if stored.isEmpty {
                    let samples = Self.sampleContacts()
                    for s in samples {
                        let contact = Contact(name: s.name, tier: s.tier, phone: s.phone, lastContacted: s.lastContacted, checkInDays: s.checkInDays, relationship: s.relationship)
                        if let bday = s.birthday {
                            contact.birthday = bday
                        }
                        persistence.saveContact(contact)
                        state.contacts.append(State.ContactState(id: contact.uuid, name: contact.name, tier: contact.tier, phone: contact.phone, relationship: contact.relationship, lastContacted: contact.lastContacted, checkInDays: contact.checkInDays, birthday: contact.birthday))
                    }
                } else {
                    state.contacts = stored.map { c in
                        State.ContactState(id: c.uuid, name: c.name, tier: c.tier, phone: c.phone, relationship: c.relationship, lastContacted: c.lastContacted, checkInDays: c.checkInDays, birthday: c.birthday)
                    }
                }
                return .none

            case let .tierFilterChanged(tier):
                state.selectedTier = tier
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case .toggleAddContact:
                state.showAddContact.toggle()
                if state.showAddContact {
                    state.newContactName = ""
                    state.newContactTier = "closeFriends"
                    state.newContactPhone = ""
                    state.newContactRelationship = "friend"
                    state.newContactCheckInDays = 30
                }
                return .none

            case let .newContactNameChanged(name):
                state.newContactName = name
                return .none

            case let .newContactTierChanged(tier):
                state.newContactTier = tier
                return .none

            case let .newContactPhoneChanged(phone):
                state.newContactPhone = phone
                return .none

            case let .newContactRelationshipChanged(rel):
                state.newContactRelationship = rel
                return .none

            case let .newContactCheckInDaysChanged(days):
                state.newContactCheckInDays = days
                return .none

            case .addContact:
                guard !state.newContactName.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return .none
                }
                let contact = Contact(
                    name: state.newContactName,
                    tier: state.newContactTier,
                    phone: state.newContactPhone,
                    checkInDays: state.newContactCheckInDays,
                    relationship: state.newContactRelationship
                )
                PersistenceService.shared.saveContact(contact)
                state.contacts.append(State.ContactState(
                    id: contact.uuid,
                    name: contact.name,
                    tier: contact.tier,
                    phone: contact.phone,
                    relationship: contact.relationship,
                    lastContacted: nil,
                    checkInDays: contact.checkInDays,
                    birthday: nil
                ))
                state.showAddContact = false
                HapticService.notification(.success)
                return .none

            case let .deleteContact(id):
                state.contacts.removeAll { $0.id == id }
                let persistence = PersistenceService.shared
                let stored = persistence.fetchContacts()
                if let match = stored.first(where: { $0.uuid == id }) {
                    persistence.deleteContact(match)
                }
                return .none

            case let .markContacted(id):
                if let index = state.contacts.firstIndex(where: { $0.id == id }) {
                    state.contacts[index].lastContacted = Date()
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchContacts()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.lastContacted = Date()
                        persistence.updateContacts()
                    }
                    HapticService.impact(.light)
                }
                return .none
            }
        }
    }

    private static func sampleContacts() -> [State.ContactState] {
        let cal = Calendar.current
        return [
            .init(id: UUID(), name: "Marcus Johnson", tier: "innerCircle", phone: "555-0101", relationship: "friend",
                  lastContacted: cal.date(byAdding: .day, value: -3, to: Date()), checkInDays: 7,
                  birthday: cal.date(from: DateComponents(month: 6, day: 15))),
            .init(id: UUID(), name: "Devon Williams", tier: "innerCircle", phone: "555-0102", relationship: "friend",
                  lastContacted: cal.date(byAdding: .day, value: -14, to: Date()), checkInDays: 14,
                  birthday: cal.date(from: DateComponents(month: 9, day: 22))),
            .init(id: UUID(), name: "James Carter", tier: "closeFriends", phone: "555-0103", relationship: "colleague",
                  lastContacted: cal.date(byAdding: .day, value: -45, to: Date()), checkInDays: 30, birthday: nil),
            .init(id: UUID(), name: "Aisha Thompson", tier: "closeFriends", phone: "555-0104", relationship: "friend",
                  lastContacted: cal.date(byAdding: .day, value: -20, to: Date()), checkInDays: 30,
                  birthday: cal.date(from: DateComponents(month: 4, day: 8))),
            .init(id: UUID(), name: "Robert King", tier: "extended", phone: "555-0105", relationship: "family",
                  lastContacted: cal.date(byAdding: .day, value: -60, to: Date()), checkInDays: 60, birthday: nil),
            .init(id: UUID(), name: "Lisa Park", tier: "extended", phone: "555-0106", relationship: "mentor",
                  lastContacted: cal.date(byAdding: .day, value: -90, to: Date()), checkInDays: 60, birthday: nil),
        ]
    }
}
