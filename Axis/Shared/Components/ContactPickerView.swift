import Contacts
import SwiftUI

struct ContactPickerView: View {
    struct SelectableContact: Equatable, Identifiable {
        let id: String
        let name: String
        let phone: String
        let email: String
        let birthday: Date?
    }

    @Environment(\.dismiss) private var dismiss
    @State private var contacts: [SelectableContact] = []
    @State private var searchText = ""
    @State private var selectAll = false
    @State private var deselectedIds = Set<String>()
    @State private var selectedIds = Set<String>()
    @State private var useSelectAllMode = false
    @State private var accessDenied = false
    @State private var isLoading = false
    @State private var hasAttemptedLoad = false
    @State private var loadErrorMessage: String?

    var onContactsSelected: ([SelectableContact]) -> Void

    private var filteredContacts: [SelectableContact] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return contacts
        }
        let query = searchText.lowercased()
        return contacts.filter { contact in
            contact.name.lowercased().contains(query)
                || contact.phone.lowercased().contains(query)
                || contact.email.lowercased().contains(query)
        }
    }

    private func isSelected(_ id: String) -> Bool {
        if useSelectAllMode {
            return !deselectedIds.contains(id)
        }
        return selectedIds.contains(id)
    }

    private var selectedCount: Int {
        if useSelectAllMode {
            return contacts.count - deselectedIds.count
        }
        return selectedIds.count
    }

    private var effectiveSelectedContacts: [SelectableContact] {
        if useSelectAllMode {
            return contacts.filter { !deselectedIds.contains($0.id) }
        }
        return contacts.filter { selectedIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if accessDenied {
                    ContentUnavailableView(
                        "Contacts Access Needed",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Enable Contacts access in Settings to import people into Social Circle.")
                    )
                } else if isLoading {
                    ProgressView("Loading contacts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.crop.square.stack.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(.purple)
                        Text(hasAttemptedLoad ? "No contacts available" : "Import from Contacts")
                            .font(.headline)
                        Text("Load your Apple Contacts, then import all or select specific ones.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        if let loadErrorMessage {
                            Text(loadErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Button {
                            Task { await loadContacts() }
                        } label: {
                            Text("Load Contacts")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.purple.opacity(0.15))
                                .foregroundStyle(.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    contactListView
                }
            }
            .navigationTitle("Import Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import \(selectedCount > 0 ? "(\(selectedCount))" : "")") {
                        onContactsSelected(effectiveSelectedContacts)
                        dismiss()
                    }
                    .disabled(selectedCount == 0)
                }
            }
        }
    }

    // MARK: - Contact List

    private var contactListView: some View {
        VStack(spacing: 0) {
            // Search + actions bar
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search contacts", text: $searchText)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack {
                    Text("\(selectedCount) of \(contacts.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()

                    Button {
                        // Import all immediately — no per-row re-render
                        onContactsSelected(contacts)
                        dismiss()
                    } label: {
                        Text("Import All (\(contacts.count))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple)
                            .foregroundStyle(.white)
                            .clipShape(.capsule)
                    }

                    Button {
                        if useSelectAllMode && deselectedIds.isEmpty {
                            // Deselect all
                            useSelectAllMode = false
                            selectedIds.removeAll()
                        } else {
                            // Select all
                            useSelectAllMode = true
                            deselectedIds.removeAll()
                            selectedIds.removeAll()
                        }
                    } label: {
                        Text(useSelectAllMode && deselectedIds.isEmpty ? "Deselect All" : "Select All")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Use List for efficient rendering
            List(filteredContacts) { contact in
                Button {
                    toggleSelection(for: contact.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected(contact.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected(contact.id) ? .purple : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name.isEmpty ? "Unnamed Contact" : contact.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            if !contact.phone.isEmpty {
                                Text(contact.phone)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if !contact.email.isEmpty {
                                Text(contact.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .listStyle(.plain)
        }
    }

    private func toggleSelection(for id: String) {
        if useSelectAllMode {
            if deselectedIds.contains(id) {
                deselectedIds.remove(id)
            } else {
                deselectedIds.insert(id)
            }
        } else {
            if selectedIds.contains(id) {
                selectedIds.remove(id)
            } else {
                selectedIds.insert(id)
            }
        }
    }

    @MainActor
    private func loadContacts() async {
        isLoading = true
        hasAttemptedLoad = true
        loadErrorMessage = nil
        defer { isLoading = false }
        do {
            let granted = try await requestAccessIfNeeded()
            guard granted else {
                accessDenied = true
                return
            }
            contacts = try await fetchContacts()
        } catch {
            loadErrorMessage = "Unable to load contacts right now."
        }
    }

    private func requestAccessIfNeeded() async throws -> Bool {
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        @unknown default:
            return false
        }
    }

    private func fetchContacts() async throws -> [SelectableContact] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let store = CNContactStore()
                let keys: [CNKeyDescriptor] = [
                    CNContactIdentifierKey as CNKeyDescriptor,
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor,
                    CNContactPhoneNumbersKey as CNKeyDescriptor,
                    CNContactEmailAddressesKey as CNKeyDescriptor,
                    CNContactBirthdayKey as CNKeyDescriptor
                ]
                let request = CNContactFetchRequest(keysToFetch: keys)
                var loaded: [SelectableContact] = []

                do {
                    try store.enumerateContacts(with: request) { contact, _ in
                        let name = [contact.givenName, contact.familyName]
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                        let bday = contact.birthday?.date
                        loaded.append(
                            SelectableContact(
                                id: contact.identifier,
                                name: name,
                                phone: contact.phoneNumbers.first?.value.stringValue ?? "",
                                email: (contact.emailAddresses.first?.value as String?) ?? "",
                                birthday: bday
                            )
                        )
                    }
                    let sorted = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    continuation.resume(returning: sorted)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

#Preview {
    ContactPickerView(onContactsSelected: { _ in })
}
