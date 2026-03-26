import ComposableArchitecture
import SwiftUI

struct GroupManagementView: View {
    @Bindable var store: StoreOf<SocialCircleReducer>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        store.send(.toggleAddGroup)
                    } label: {
                        Label("New Group", systemImage: "plus.circle.fill")
                            .foregroundStyle(.purple)
                    }
                }

                Section("Groups") {
                    if store.groups.isEmpty {
                        Text("No groups yet. Create one to organize your contacts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.groups) { group in
                        HStack {
                            Text(group.emoji)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(group.memberIds.count) member\(group.memberIds.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.send(.deleteGroup(group.id))
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.send(.dismissGroupManagement) }
                }
            }
            .alert("New Group", isPresented: Binding(
                get: { store.showAddGroup },
                set: { newValue in
                    if !newValue { store.send(.dismissAddGroup) }
                }
            )) {
                TextField("Group name", text: $store.newGroupName.sending(\.newGroupNameChanged))
                Button("Create") { store.send(.addGroup) }
                Button("Cancel", role: .cancel) { store.send(.dismissAddGroup) }
            }
        }
    }
}
