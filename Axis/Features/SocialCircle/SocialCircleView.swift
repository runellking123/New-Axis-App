import ComposableArchitecture
import ContactsUI
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

                // Tier filter chips + Group filter
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
                                        store.selectedTier == tier && store.selectedGroupFilter == nil
                                            ? Color.purple.opacity(0.2)
                                            : Color(.systemGray5)
                                    )
                                    .foregroundStyle(
                                        store.selectedTier == tier && store.selectedGroupFilter == nil
                                            ? .purple
                                            : .secondary
                                    )
                                    .clipShape(Capsule())
                            }
                        }

                        if !store.groups.isEmpty {
                            Divider().frame(height: 20)
                            ForEach(store.groups) { group in
                                Button {
                                    store.send(.setGroupFilter(store.selectedGroupFilter == group.id ? nil : group.id))
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(group.emoji)
                                            .font(.caption2)
                                        Text(group.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(store.selectedGroupFilter == group.id ? Color.purple.opacity(0.2) : Color(.systemGray5))
                                    .foregroundStyle(store.selectedGroupFilter == group.id ? .purple : .secondary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                ScrollView {
                    VStack(spacing: 16) {
                        // Insights dashboard
                        if store.showInsights {
                            insightsSection
                        }

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
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Social Circle")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.purple)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.send(.toggleGroupManagement)
                    } label: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.purple)
                    }
                    .accessibilityLabel("Manage groups")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            store.send(.toggleInsights)
                        } label: {
                            Image(systemName: store.showInsights ? "chart.bar.fill" : "chart.bar")
                                .foregroundStyle(.purple)
                        }
                        .accessibilityLabel("Toggle insights")

                        Button {
                            store.send(.showContactPicker)
                        } label: {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundStyle(.purple)
                        }
                        .accessibilityLabel("Import contacts")

                        Button {
                            store.send(.toggleAddContact)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.purple)
                        }
                        .accessibilityLabel("Add contact manually")
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddContact },
                set: { newValue in
                    if !newValue { store.send(.dismissAddContact) }
                }
            )) {
                addContactSheet
            }
            .sheet(isPresented: Binding(
                get: { store.showContactPicker },
                set: { newValue in
                    if !newValue { store.send(.dismissContactPicker) }
                }
            )) {
                ContactPickerView { cnContacts in
                    let imported = cnContacts.map { cn in
                        let name = [cn.givenName, cn.familyName]
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                        let phone = cn.phoneNumbers.first?.value.stringValue ?? ""
                        let email = (cn.emailAddresses.first?.value as String?) ?? ""
                        var birthday: Date?
                        if let bday = cn.birthday {
                            birthday = Calendar.current.date(from: bday)
                        }
                        return SocialCircleReducer.ImportedContact(
                            name: name,
                            phone: phone,
                            email: email,
                            birthday: birthday
                        )
                    }
                    store.send(.importContacts(imported))
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showGroupManagement },
                set: { if !$0 { store.send(.toggleGroupManagement) } }
            )) {
                GroupManagementView(store: store)
            }
            .sheet(isPresented: Binding(
                get: { store.showInteractionLog },
                set: { if !$0 { store.send(.dismissInteractionLog) } }
            )) {
                InteractionLogView(store: store)
            }
            .navigationDestination(isPresented: Binding(
                get: { store.selectedContactId != nil },
                set: { if !$0 { store.send(.selectContact(nil)) } }
            )) {
                if let id = store.selectedContactId, let contact = store.contacts.first(where: { $0.id == id }) {
                    ContactDetailView(store: store, contact: contact)
                }
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

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.purple)
                Text("Relationship Insights")
                    .font(.headline)
            }

            // Tier distribution
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Circle Distribution")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if store.contacts.isEmpty {
                        Text("Import contacts to see insights")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        let total = max(store.contacts.count, 1)
                        tierBar(label: "Inner Circle", count: store.innerCircleCount, total: total, color: .yellow)
                        tierBar(label: "Close Friends", count: store.closeFriendsCount, total: total, color: .purple)
                        tierBar(label: "Extended", count: store.extendedCount, total: total, color: .gray)
                    }
                }
            }

            // Most connected / neglected
            if !store.mostConnected.isEmpty {
                HStack(spacing: 12) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "hand.thumbsup.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Text("Most Connected")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            ForEach(store.mostConnected) { c in
                                HStack {
                                    Text(c.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(c.daysSinceContact)d")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("Most Neglected")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            ForEach(store.mostNeglected) { c in
                                HStack {
                                    Text(c.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(c.lastContacted != nil ? "\(c.daysSinceContact)d" : "Never")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func tierBar(label: String, count: Int, total: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.6))
                        .frame(width: max(geo.size.width * CGFloat(count) / CGFloat(total), 4))
                }
            }
            .frame(height: 12)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
                .frame(width: 24, alignment: .trailing)
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
                    Button {
                        store.send(.selectContact(contact.id))
                    } label: {
                        contactCard(contact)
                    }
                    .buttonStyle(.plain)
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
                        if !contact.phone.isEmpty {
                            Text(formatPhone(contact.phone))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Health score + Days since contact
                    VStack(alignment: .trailing, spacing: 2) {
                        // Health score badge
                        Text("\(contact.healthScore)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .frame(width: 28, height: 28)
                            .background(healthColor(contact.healthColor).opacity(0.15))
                            .foregroundStyle(healthColor(contact.healthColor))
                            .clipShape(Circle())

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
                    }
                }

                // Action buttons
                HStack(spacing: 6) {
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
                            openURL("tel://\(sanitizedPhoneDigits(contact.phone))")
                            store.send(.markContacted(contact.id))
                        } label: {
                            Image(systemName: "phone.fill")
                                .font(.caption2)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Button {
                            openURL("sms:\(sanitizedPhoneDigits(contact.phone))")
                            store.send(.markContacted(contact.id))
                        } label: {
                            Image(systemName: "message.fill")
                                .font(.caption2)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Button {
                            openURL("facetime://\(sanitizedPhoneDigits(contact.phone))")
                            store.send(.markContacted(contact.id))
                        } label: {
                            Image(systemName: "video.fill")
                                .font(.caption2)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if let email = contact.email, !email.isEmpty {
                        Button {
                            openURL("mailto:\(email)")
                            store.send(.markContacted(contact.id))
                        } label: {
                            Image(systemName: "envelope.fill")
                                .font(.caption2)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.orange)
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

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "innerCircle": return .yellow
        case "closeFriends": return .purple
        case "extended": return .gray
        default: return .gray
        }
    }

    private func healthColor(_ color: String) -> Color {
        switch color {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }

    private func sanitizedPhoneDigits(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        if digits.count == 10 { return digits }
        if digits.count == 11, digits.hasPrefix("1") { return String(digits.dropFirst()) }
        return digits
    }

    private func formatPhone(_ value: String) -> String {
        let digits = sanitizedPhoneDigits(value)
        guard digits.count == 10 else { return value }
        return "\(digits.prefix(3))-\(digits.dropFirst(3).prefix(3))-\(digits.suffix(4))"
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
                    Button("Cancel") { store.send(.dismissAddContact) }
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
