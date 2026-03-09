import ComposableArchitecture
import SwiftUI

struct ContactDetailView: View {
    @Bindable var store: StoreOf<SocialCircleReducer>
    let contact: SocialCircleReducer.State.ContactState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Contact header with health score
                GlassCard {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(tierColor(contact.tier).opacity(0.2))
                                .frame(width: 72, height: 72)
                            Text(contact.initials)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(tierColor(contact.tier))
                        }

                        Text(contact.name)
                            .font(.title3)
                            .fontWeight(.bold)

                        HStack(spacing: 8) {
                            Image(systemName: contact.tierIcon)
                                .font(.caption)
                                .foregroundStyle(tierColor(contact.tier))
                            Text(contact.tierLabel)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(tierColor(contact.tier))
                        }

                        // Health score badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(healthScoreColor(contact.healthColor))
                                .frame(width: 8, height: 8)
                            Text("Health: \(contact.healthScore)/100")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(healthScoreColor(contact.healthColor))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(healthScoreColor(contact.healthColor).opacity(0.1))
                        .clipShape(Capsule())

                        if contact.lastContacted != nil {
                            Text("\(contact.daysSinceContact) days since last contact")
                                .font(.caption)
                                .foregroundStyle(contact.isOverdue ? .orange : .secondary)
                        } else {
                            Text("Never contacted")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Quick actions
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Actions")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 10) {
                            if !contact.phone.isEmpty {
                                actionButton(icon: "phone.fill", label: "Call", color: .green) {
                                    openURL("tel://\(sanitizedPhone(contact.phone))")
                                    store.send(.markContacted(contact.id))
                                }
                                actionButton(icon: "message.fill", label: "Text", color: .blue) {
                                    openURL("sms:\(sanitizedPhone(contact.phone))")
                                    store.send(.markContacted(contact.id))
                                }
                                actionButton(icon: "video.fill", label: "FaceTime", color: .green) {
                                    openURL("facetime://\(sanitizedPhone(contact.phone))")
                                    store.send(.markContacted(contact.id))
                                }
                            }
                            if let email = contact.email, !email.isEmpty {
                                actionButton(icon: "envelope.fill", label: "Email", color: .orange) {
                                    openURL("mailto:\(email)")
                                    store.send(.markContacted(contact.id))
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Button {
                                store.send(.markContacted(contact.id))
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Checked In")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.purple.opacity(0.15))
                                .foregroundStyle(.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button {
                                store.send(.showInteractionLog(contact.id))
                            } label: {
                                HStack {
                                    Image(systemName: "plus.bubble.fill")
                                    Text("Log")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }

                // Interaction History
                if !contact.interactions.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.purple)
                                Text("Interaction History")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(contact.interactions.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(contact.interactions.prefix(10)) { interaction in
                                HStack(spacing: 10) {
                                    Image(systemName: interaction.typeIcon)
                                        .font(.caption)
                                        .foregroundStyle(.purple)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(interaction.type.capitalized)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        if !interaction.notes.isEmpty {
                                            Text(interaction.notes)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    Text(interaction.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Button {
                                        store.send(.deleteInteraction(contact.id, interaction.id))
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                // Groups
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Groups")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if store.groups.isEmpty {
                            Text("No groups created yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(store.groups) { group in
                                        let isMember = contact.groupIds.contains(group.id)
                                        Button {
                                            if isMember {
                                                store.send(.removeContactFromGroup(contact.id, group.id))
                                            } else {
                                                store.send(.addContactToGroup(contact.id, group.id))
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(group.emoji)
                                                    .font(.caption2)
                                                Text(group.name)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(isMember ? Color.purple.opacity(0.15) : Color(.systemGray5))
                                            .foregroundStyle(isMember ? .purple : .secondary)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Tier
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tier")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 12) {
                            tierChip("innerCircle", icon: "star.circle.fill", label: "Inner", color: .yellow)
                            tierChip("closeFriends", icon: "heart.circle.fill", label: "Close", color: .purple)
                            tierChip("extended", icon: "person.circle.fill", label: "Extended", color: .gray)
                        }
                    }
                }

                // Relationship
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Relationship")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            relationshipChip("friend")
                            relationshipChip("colleague")
                            relationshipChip("family")
                            relationshipChip("mentor")
                        }
                    }
                }

                // Check-in cadence
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Check-in Cadence")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            ForEach([7, 14, 30, 60, 90], id: \.self) { days in
                                Button {
                                    store.send(.updateContactCadence(contact.id, days))
                                } label: {
                                    Text("\(days)d")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(contact.checkInDays == days ? Color.purple.opacity(0.2) : Color(.systemGray5))
                                        .foregroundStyle(contact.checkInDays == days ? .purple : .secondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                // Contact info
                if !contact.phone.isEmpty || (contact.email != nil && !contact.email!.isEmpty) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contact Info")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if !contact.phone.isEmpty {
                                HStack {
                                    Image(systemName: "phone")
                                        .foregroundStyle(.green)
                                    Text(formatPhone(contact.phone))
                                        .font(.subheadline)
                                }
                            }
                            if let email = contact.email, !email.isEmpty {
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundStyle(.orange)
                                    Text(email)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }

                // Birthday
                if let birthday = contact.birthday {
                    GlassCard {
                        HStack {
                            Image(systemName: "gift.fill")
                                .foregroundStyle(.pink)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Birthday")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(birthday.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                            }
                            Spacer()
                            if let days = contact.daysUntilBirthday {
                                Text(days == 0 ? "Today!" : "in \(days) days")
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

                // Rich Notes
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Interests, topics, reminders...", text: Binding(
                            get: { contact.richNotes },
                            set: { store.send(.updateContactNotes(contact.id, $0)) }
                        ), axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(3...8)
                    }
                }

                // Delete
                Button(role: .destructive) {
                    store.send(.deleteContact(contact.id))
                    store.send(.selectContact(nil))
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Contact")
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
        .navigationTitle(contact.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.callout)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func tierChip(_ key: String, icon: String, label: String, color: Color) -> some View {
        Button {
            store.send(.updateContactTier(contact.id, key))
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(contact.tier == key ? color.opacity(0.2) : Color(.systemGray5))
            .foregroundStyle(contact.tier == key ? color : .secondary)
            .clipShape(Capsule())
        }
    }

    private func relationshipChip(_ value: String) -> some View {
        Button {
            store.send(.updateContactRelationship(contact.id, value))
        } label: {
            Text(value.capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(contact.relationship == value ? Color.purple.opacity(0.2) : Color(.systemGray5))
                .foregroundStyle(contact.relationship == value ? .purple : .secondary)
                .clipShape(Capsule())
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

    private func healthScoreColor(_ color: String) -> Color {
        switch color {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        guard UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    private func sanitizedPhone(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        if digits.count == 10 { return digits }
        if digits.count == 11, digits.hasPrefix("1") { return String(digits.dropFirst()) }
        return digits
    }

    private func formatPhone(_ value: String) -> String {
        let digits = sanitizedPhone(value)
        guard digits.count == 10 else { return value }
        return "\(digits.prefix(3))-\(digits.dropFirst(3).prefix(3))-\(digits.suffix(4))"
    }
}
