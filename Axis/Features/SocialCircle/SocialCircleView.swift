import ComposableArchitecture
import SwiftUI
import UIKit

struct SocialCircleView: View {
    @Bindable var store: StoreOf<SocialCircleReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search contacts...", text: $store.searchText.sending(\.searchTextChanged))
                        .font(.subheadline)
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 8)

                // Tier filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SocialCircleReducer.State.TierFilter.allCases, id: \.self) { tier in
                            Button {
                                store.send(.tierFilterChanged(tier))
                            } label: {
                                Text(tier.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        store.selectedTier == tier
                                            ? Color.purple.opacity(0.2)
                                            : Color(.systemGray5)
                                    )
                                    .foregroundStyle(
                                        store.selectedTier == tier
                                            ? .purple
                                            : .secondary
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                ScrollView {
                    VStack(spacing: 16) {
                        // Overdue alerts
                        if store.overdueCount > 0 {
                            overdueAlert
                        }

                        // Upcoming birthdays
                        if !store.upcomingBirthdays.isEmpty {
                            birthdaySection
                        }

                        // Contact list
                        contactsList
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Social Circle")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.purple)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.send(.toggleAddContact)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.purple)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddContact },
                set: { _ in store.send(.toggleAddContact) }
            )) {
                addContactSheet
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    // MARK: - Overdue Alert

    private var overdueAlert: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.overdueCount) check-in\(store.overdueCount == 1 ? "" : "s") overdue")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Time to reach out to people who matter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Birthday Section

    private var birthdaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.pink)
                Text("Upcoming Birthdays")
                    .font(.headline)
            }

            ForEach(store.upcomingBirthdays) { contact in
                GlassCard {
                    HStack(spacing: 12) {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(.pink)
                            .frame(width: 24)

                        Text(contact.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        if let days = contact.daysUntilBirthday {
                            Text(days == 0 ? "Today!" : "in \(days)d")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(days <= 7 ? Color.pink.opacity(0.15) : Color(.systemGray5))
                                .foregroundStyle(days <= 7 ? .pink : .secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Contacts List

    private var contactsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Contacts")
                    .font(.headline)
                Spacer()
                Text("\(store.filteredContacts.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            if store.filteredContacts.isEmpty {
                GlassCard {
                    HStack {
                        Image(systemName: "person.slash")
                            .foregroundStyle(.secondary)
                        Text("No contacts match your filters.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(store.filteredContacts) { contact in
                    contactCard(contact)
                }
            }
        }
    }

    private func contactCard(_ contact: SocialCircleReducer.State.ContactState) -> some View {
        GlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(tierColor(contact.tier).opacity(0.2))
                            .frame(width: 40, height: 40)
                        Text(contact.initials)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(tierColor(contact.tier))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(contact.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: contact.tierIcon)
                                .font(.caption2)
                                .foregroundStyle(tierColor(contact.tier))
                        }
                        Text(contact.relationship.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Days since contact
                    VStack(alignment: .trailing, spacing: 2) {
                        if contact.lastContacted != nil {
                            Text("\(contact.daysSinceContact)d ago")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(contact.isOverdue ? .orange : .secondary)
                        } else {
                            Text("Never")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Text("every \(contact.checkInDays)d")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        store.send(.markContacted(contact.id))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                            Text("Checked In")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if !contact.phone.isEmpty {
                        Button {
                            if let url = URL(string: "sms:\(contact.phone)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "message.fill")
                                    .font(.caption2)
                                Text("Message")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    Button {
                        store.send(.deleteContact(contact.id))
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

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "innerCircle": return .yellow
        case "closeFriends": return .purple
        case "extended": return .gray
        default: return .gray
        }
    }

    // MARK: - Add Contact Sheet

    private var addContactSheet: some View {
        NavigationStack {
            Form {
                Section("Contact Info") {
                    TextField("Name", text: $store.newContactName.sending(\.newContactNameChanged))
                    TextField("Phone (optional)", text: $store.newContactPhone.sending(\.newContactPhoneChanged))
                        .keyboardType(.phonePad)
                }

                Section("Relationship") {
                    Picker("Tier", selection: $store.newContactTier.sending(\.newContactTierChanged)) {
                        Label("Inner Circle", systemImage: "star.circle.fill").tag("innerCircle")
                        Label("Close Friends", systemImage: "heart.circle.fill").tag("closeFriends")
                        Label("Extended", systemImage: "person.circle.fill").tag("extended")
                    }

                    Picker("Type", selection: $store.newContactRelationship.sending(\.newContactRelationshipChanged)) {
                        Text("Friend").tag("friend")
                        Text("Colleague").tag("colleague")
                        Text("Family").tag("family")
                        Text("Mentor").tag("mentor")
                    }
                }

                Section("Check-in Cadence") {
                    Picker("Reach out every", selection: $store.newContactCheckInDays.sending(\.newContactCheckInDaysChanged)) {
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                        Text("60 days").tag(60)
                        Text("90 days").tag(90)
                    }
                }
            }
            .navigationTitle("New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.toggleAddContact) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { store.send(.addContact) }
                        .fontWeight(.semibold)
                        .disabled(store.newContactName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}
