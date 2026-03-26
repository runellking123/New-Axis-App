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
        var showContactPicker = false
        var importTier = "closeFriends"
        var showImportTierPicker = false
        var pendingImports: [ImportedContact] = []

        // Phase 2: Groups
        var groups: [GroupState] = []
        var selectedGroupFilter: UUID?
        var showGroupManagement = false
        var showAddGroup = false
        var newGroupName = ""
        var newGroupEmoji = "👥"

        // Phase 2: Interactions
        var showInteractionLog = false
        var interactionContactId: UUID?
        var newInteractionType = "call"
        var newInteractionNotes = ""
        var newInteractionDate = Date()

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

        struct GroupState: Equatable, Identifiable {
            let id: UUID
            var name: String
            var emoji: String
            var memberIds: [UUID]
        }

        struct InteractionState: Equatable, Identifiable {
            let id: UUID
            var type: String
            var date: Date
            var notes: String

            var typeIcon: String {
                switch type {
                case "call": return "phone.fill"
                case "text": return "message.fill"
                case "coffee": return "cup.and.saucer.fill"
                case "meeting": return "person.2.fill"
                case "email": return "envelope.fill"
                case "facetime": return "video.fill"
                default: return "bubble.left.fill"
                }
            }
        }

        struct ContactState: Equatable, Identifiable {
            let id: UUID
            var name: String
            var tier: String
            var phone: String
            var email: String?
            var relationship: String
            var lastContacted: Date?
            var checkInDays: Int
            var birthday: Date?
            var richNotes: String
            var groupIds: [UUID]
            var interactions: [InteractionState]

            init(id: UUID, name: String, tier: String, phone: String, email: String? = nil, relationship: String, lastContacted: Date? = nil, checkInDays: Int = 30, birthday: Date? = nil, richNotes: String = "", groupIds: [UUID] = [], interactions: [InteractionState] = []) {
                self.id = id
                self.name = name
                self.tier = tier
                self.phone = phone
                self.email = email
                self.relationship = relationship
                self.lastContacted = lastContacted
                self.checkInDays = checkInDays
                self.birthday = birthday
                self.richNotes = richNotes
                self.groupIds = groupIds
                self.interactions = interactions
            }

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

            // Phase 2: Health Score
            var healthScore: Int {
                let daysSince = daysSinceContact
                guard checkInDays > 0 else { return 50 }
                let ratio = Double(daysSince) / Double(checkInDays)

                let tierWeight: Double
                switch tier {
                case "innerCircle": tierWeight = 3.0
                case "closeFriends": tierWeight = 2.0
                default: tierWeight = 1.0
                }

                var score = 100.0 - (ratio * 30.0 * tierWeight)

                // Bonus for recent interactions
                let recentCount = interactions.filter {
                    Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 999 <= 7
                }.count
                score += Double(recentCount) * 5.0

                return max(0, min(100, Int(score)))
            }

            var healthColor: String {
                if healthScore > 70 { return "green" }
                if healthScore > 40 { return "yellow" }
                return "red"
            }
        }

        var filteredContacts: [ContactState] {
            var result = contacts
            if showOverdueOnly {
                result = result.filter(\.isOverdue)
            }
            if let key = selectedTier.filterKey {
                result = result.filter { $0.tier == key }
            }
            if let groupId = selectedGroupFilter {
                result = result.filter { $0.groupIds.contains(groupId) }
            }
            if !searchText.isEmpty {
                result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            return result.sorted {
                if showOverdueOnly || sortByLastContacted {
                    return $0.daysSinceContact > $1.daysSinceContact
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        var overdueCount: Int {
            contacts.filter(\.isOverdue).count
        }

        var upcomingBirthdays: [ContactState] {
            contacts
                .filter { $0.daysUntilBirthday != nil && ($0.daysUntilBirthday ?? 999) <= 30 }
                .sorted { ($0.daysUntilBirthday ?? 999) < ($1.daysUntilBirthday ?? 999) }
        }

        var innerCircleCount: Int { contacts.filter { $0.tier == "innerCircle" }.count }
        var closeFriendsCount: Int { contacts.filter { $0.tier == "closeFriends" }.count }
        var extendedCount: Int { contacts.filter { $0.tier == "extended" }.count }

        var mostConnected: [ContactState] {
            contacts
                .filter { $0.lastContacted != nil }
                .sorted { $0.daysSinceContact < $1.daysSinceContact }
                .prefix(3)
                .map { $0 }
        }

        var mostNeglected: [ContactState] {
            contacts
                .sorted { $0.daysSinceContact > $1.daysSinceContact }
                .prefix(3)
                .map { $0 }
        }

        var averageHealthScore: Int {
            guard !contacts.isEmpty else { return 0 }
            let total = contacts.reduce(0) { $0 + $1.healthScore }
            return total / contacts.count
        }

        var sortByLastContacted: Bool = false
        var showInsights: Bool = false
        var showOverdueOnly: Bool = false
        var selectedContactId: UUID?
        var isLoadingContacts: Bool = false
    }

    enum Action: Equatable {
        case onAppear
        case contactsLoaded([State.ContactState], [State.GroupState])
        case tierFilterChanged(State.TierFilter)
        case searchTextChanged(String)
        case toggleAddContact
        case dismissAddContact
        case showContactPicker
        case dismissContactPicker
        case importContacts([ImportedContact])
        case importTierChanged(String)
        case confirmImportWithTier
        case dismissImportTierPicker
        case newContactNameChanged(String)
        case newContactTierChanged(String)
        case newContactPhoneChanged(String)
        case newContactRelationshipChanged(String)
        case newContactCheckInDaysChanged(Int)
        case addContact
        case deleteContact(UUID)
        case markContacted(UUID)
        case toggleInsights
        case toggleOverdueFilter
        case toggleSortByLastContacted
        // Drill-down
        case selectContact(UUID?)
        case updateContactTier(UUID, String)
        case updateContactRelationship(UUID, String)
        case updateContactCadence(UUID, Int)
        // Phase 2: Rich Notes
        case updateContactNotes(UUID, String)
        // Phase 2: Groups
        case toggleGroupManagement
        case dismissGroupManagement
        case toggleAddGroup
        case dismissAddGroup
        case newGroupNameChanged(String)
        case newGroupEmojiChanged(String)
        case addGroup
        case deleteGroup(UUID)
        case addContactToGroup(UUID, UUID) // contactId, groupId
        case removeContactFromGroup(UUID, UUID)
        case setGroupFilter(UUID?)
        // Phase 2: Interactions
        case showInteractionLog(UUID)
        case dismissInteractionLog
        case newInteractionTypeChanged(String)
        case newInteractionNotesChanged(String)
        case newInteractionDateChanged(Date)
        case logInteraction
        case deleteInteraction(UUID, UUID) // contactId, interactionId
    }

    struct ImportedContact: Equatable {
        var name: String
        var phone: String
        var email: String
        var birthday: Date?
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let persistence = PersistenceService.shared
                let stored = persistence.fetchContacts()
                state.contacts = stored.map { c in
                    let interactions = persistence.fetchInteractions(forContact: c.uuid).map { i in
                        State.InteractionState(id: i.uuid, type: i.type, date: i.date, notes: i.notes)
                    }
                    return State.ContactState(
                        id: c.uuid, name: c.name, tier: c.tier, phone: c.phone,
                        email: c.email.isEmpty ? nil : c.email, relationship: c.relationship,
                        lastContacted: c.lastContacted, checkInDays: c.checkInDays,
                        birthday: c.birthday, richNotes: c.richNotes ?? "",
                        groupIds: c.groupIds ?? [], interactions: interactions
                    )
                }
                let groups = persistence.fetchContactGroups()
                state.groups = groups.map { g in
                    State.GroupState(id: g.uuid, name: g.name, emoji: g.emoji, memberIds: g.memberIds)
                }
                NotificationService.shared.scheduleCheckInReminders()
                return .none

            case let .contactsLoaded(contacts, groups):
                state.contacts = contacts
                state.groups = groups
                state.isLoadingContacts = false
                NotificationService.shared.scheduleCheckInReminders()
                return .none

            case let .tierFilterChanged(tier):
                state.selectedTier = tier
                state.selectedGroupFilter = nil
                state.showOverdueOnly = false
                return .none

            case .toggleOverdueFilter:
                state.showOverdueOnly.toggle()
                return .none

            case .toggleSortByLastContacted:
                state.sortByLastContacted.toggle()
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

            case .dismissAddContact:
                state.showAddContact = false
                return .none

            case .showContactPicker:
                state.showContactPicker = true
                return .none

            case .dismissContactPicker:
                state.showContactPicker = false
                return .none

            case let .importContacts(imported):
                state.showContactPicker = false
                if imported.isEmpty { return .none }
                // Auto-import with default tier (skip tier picker)
                let tier = "closeFriends"
                let persistence = PersistenceService.shared
                let existingPhones = Set(state.contacts.compactMap { Self.sanitizePhone($0.phone) })

                for ic in imported {
                    let sanitized = Self.sanitizePhone(ic.phone)
                    if let sanitized, existingPhones.contains(sanitized) { continue }
                    let contact = Contact(
                        name: ic.name, tier: tier, phone: ic.phone,
                        email: ic.email, birthday: ic.birthday, checkInDays: 30, relationship: "friend"
                    )
                    persistence.saveContact(contact)
                    state.contacts.append(State.ContactState(
                        id: contact.uuid, name: contact.name, tier: contact.tier,
                        phone: contact.phone, email: contact.email.isEmpty ? nil : contact.email,
                        relationship: contact.relationship, lastContacted: nil,
                        checkInDays: contact.checkInDays, birthday: contact.birthday
                    ))
                }
                HapticService.notification(.success)
                return .none

            case let .importTierChanged(tier):
                state.importTier = tier
                return .none

            case .confirmImportWithTier:
                state.showImportTierPicker = false
                let tier = state.importTier
                let persistence = PersistenceService.shared
                let existingPhones = Set(state.contacts.compactMap { Self.sanitizePhone($0.phone) })

                for ic in state.pendingImports {
                    let sanitized = Self.sanitizePhone(ic.phone)
                    if let sanitized, existingPhones.contains(sanitized) { continue }
                    let contact = Contact(
                        name: ic.name, tier: tier, phone: ic.phone,
                        email: ic.email, birthday: ic.birthday, checkInDays: 30, relationship: "friend"
                    )
                    persistence.saveContact(contact)
                    state.contacts.append(State.ContactState(
                        id: contact.uuid, name: contact.name, tier: contact.tier,
                        phone: contact.phone, email: contact.email.isEmpty ? nil : contact.email,
                        relationship: contact.relationship, lastContacted: nil,
                        checkInDays: contact.checkInDays, birthday: contact.birthday
                    ))
                }
                state.pendingImports = []
                HapticService.notification(.success)
                return .none

            case .dismissImportTierPicker:
                state.showImportTierPicker = false
                state.pendingImports = []
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
                guard !state.newContactName.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                let contact = Contact(
                    name: state.newContactName, tier: state.newContactTier,
                    phone: state.newContactPhone, checkInDays: state.newContactCheckInDays,
                    relationship: state.newContactRelationship
                )
                PersistenceService.shared.saveContact(contact)
                state.contacts.append(State.ContactState(
                    id: contact.uuid, name: contact.name, tier: contact.tier,
                    phone: contact.phone, email: nil, relationship: contact.relationship,
                    lastContacted: nil, checkInDays: contact.checkInDays, birthday: nil
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

            case .toggleInsights:
                state.showInsights.toggle()
                return .none

            // MARK: - Drill-down

            case let .selectContact(id):
                state.selectedContactId = id
                return .none

            case let .updateContactTier(id, tier):
                if let index = state.contacts.firstIndex(where: { $0.id == id }) {
                    state.contacts[index].tier = tier
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchContacts()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.tier = tier
                        persistence.updateContacts()
                    }
                }
                return .none

            case let .updateContactRelationship(id, relationship):
                if let index = state.contacts.firstIndex(where: { $0.id == id }) {
                    state.contacts[index].relationship = relationship
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchContacts()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.relationship = relationship
                        persistence.updateContacts()
                    }
                }
                return .none

            case let .updateContactCadence(id, days):
                if let index = state.contacts.firstIndex(where: { $0.id == id }) {
                    state.contacts[index].checkInDays = days
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchContacts()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.checkInDays = days
                        persistence.updateContacts()
                    }
                }
                return .none

            // MARK: - Rich Notes

            case let .updateContactNotes(id, notes):
                if let index = state.contacts.firstIndex(where: { $0.id == id }) {
                    state.contacts[index].richNotes = notes
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchContacts()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.richNotes = notes
                        persistence.updateContacts()
                    }
                }
                return .none

            // MARK: - Groups

            case .toggleGroupManagement:
                state.showGroupManagement.toggle()
                return .none

            case .dismissGroupManagement:
                state.showGroupManagement = false
                return .none

            case .toggleAddGroup:
                state.showAddGroup.toggle()
                if state.showAddGroup {
                    state.newGroupName = ""
                    state.newGroupEmoji = "👥"
                }
                return .none

            case .dismissAddGroup:
                state.showAddGroup = false
                return .none

            case let .newGroupNameChanged(name):
                state.newGroupName = name
                return .none

            case let .newGroupEmojiChanged(emoji):
                state.newGroupEmoji = emoji
                return .none

            case .addGroup:
                guard !state.newGroupName.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                let group = ContactGroup(name: state.newGroupName, emoji: state.newGroupEmoji)
                PersistenceService.shared.saveContactGroup(group)
                state.groups.append(State.GroupState(id: group.uuid, name: group.name, emoji: group.emoji, memberIds: []))
                state.showAddGroup = false
                HapticService.notification(.success)
                return .none

            case let .deleteGroup(id):
                state.groups.removeAll { $0.id == id }
                // Remove group from all contacts
                for i in state.contacts.indices {
                    state.contacts[i].groupIds.removeAll { $0 == id }
                }
                let persistence = PersistenceService.shared
                let stored = persistence.fetchContactGroups()
                if let match = stored.first(where: { $0.uuid == id }) {
                    persistence.deleteContactGroup(match)
                }
                if state.selectedGroupFilter == id { state.selectedGroupFilter = nil }
                return .none

            case let .addContactToGroup(contactId, groupId):
                if let cIndex = state.contacts.firstIndex(where: { $0.id == contactId }),
                   !state.contacts[cIndex].groupIds.contains(groupId) {
                    state.contacts[cIndex].groupIds.append(groupId)
                    // Update group memberIds
                    if let gIndex = state.groups.firstIndex(where: { $0.id == groupId }),
                       !state.groups[gIndex].memberIds.contains(contactId) {
                        state.groups[gIndex].memberIds.append(contactId)
                    }
                    // Persist
                    let persistence = PersistenceService.shared
                    let contacts = persistence.fetchContacts()
                    if let match = contacts.first(where: { $0.uuid == contactId }) {
                        match.groupIds = state.contacts[cIndex].groupIds
                        persistence.updateContacts()
                    }
                    let groups = persistence.fetchContactGroups()
                    if let gmatch = groups.first(where: { $0.uuid == groupId }) {
                        if let gIndex = state.groups.firstIndex(where: { $0.id == groupId }) {
                            gmatch.memberIds = state.groups[gIndex].memberIds
                        }
                        persistence.updateContactGroups()
                    }
                }
                return .none

            case let .removeContactFromGroup(contactId, groupId):
                if let cIndex = state.contacts.firstIndex(where: { $0.id == contactId }) {
                    state.contacts[cIndex].groupIds.removeAll { $0 == groupId }
                    if let gIndex = state.groups.firstIndex(where: { $0.id == groupId }) {
                        state.groups[gIndex].memberIds.removeAll { $0 == contactId }
                    }
                    let persistence = PersistenceService.shared
                    let contacts = persistence.fetchContacts()
                    if let match = contacts.first(where: { $0.uuid == contactId }) {
                        match.groupIds = state.contacts[cIndex].groupIds
                        persistence.updateContacts()
                    }
                }
                return .none

            case let .setGroupFilter(id):
                state.selectedGroupFilter = id
                return .none

            // MARK: - Interactions

            case let .showInteractionLog(contactId):
                state.interactionContactId = contactId
                state.showInteractionLog = true
                state.newInteractionType = "call"
                state.newInteractionNotes = ""
                state.newInteractionDate = Date()
                return .none

            case .dismissInteractionLog:
                state.showInteractionLog = false
                state.interactionContactId = nil
                return .none

            case let .newInteractionTypeChanged(type):
                state.newInteractionType = type
                return .none

            case let .newInteractionNotesChanged(notes):
                state.newInteractionNotes = notes
                return .none

            case let .newInteractionDateChanged(date):
                state.newInteractionDate = date
                return .none

            case .logInteraction:
                guard let contactId = state.interactionContactId else { return .none }
                let interaction = Interaction(
                    contactId: contactId,
                    type: state.newInteractionType,
                    date: state.newInteractionDate,
                    notes: state.newInteractionNotes
                )
                PersistenceService.shared.saveInteraction(interaction)
                if let index = state.contacts.firstIndex(where: { $0.id == contactId }) {
                    state.contacts[index].interactions.insert(
                        State.InteractionState(id: interaction.uuid, type: interaction.type, date: interaction.date, notes: interaction.notes),
                        at: 0
                    )
                    state.contacts[index].lastContacted = interaction.date
                    // Persist lastContacted
                    let stored = PersistenceService.shared.fetchContacts()
                    if let match = stored.first(where: { $0.uuid == contactId }) {
                        match.lastContacted = interaction.date
                        PersistenceService.shared.updateContacts()
                    }
                }
                state.showInteractionLog = false
                state.interactionContactId = nil
                HapticService.notification(.success)
                return .none

            case let .deleteInteraction(contactId, interactionId):
                if let cIndex = state.contacts.firstIndex(where: { $0.id == contactId }) {
                    state.contacts[cIndex].interactions.removeAll { $0.id == interactionId }
                    let stored = PersistenceService.shared.fetchAllInteractions()
                    if let match = stored.first(where: { $0.uuid == interactionId }) {
                        PersistenceService.shared.deleteInteraction(match)
                    }
                }
                return .none
            }
        }
    }

    private static func sanitizePhone(_ value: String) -> String? {
        let digits = value.filter(\.isNumber)
        if digits.count == 10 { return digits }
        if digits.count == 11, digits.hasPrefix("1") { return String(digits.dropFirst()) }
        return digits.isEmpty ? nil : digits
    }

}
