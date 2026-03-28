import ComposableArchitecture
import SwiftUI

struct EventDetailView: View {
    @Bindable var store: StoreOf<FamilyHQReducer>
    let event: FamilyHQReducer.State.EventState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status card
                GlassCard {
                    HStack(spacing: 16) {
                        Button {
                            store.send(.toggleEventCompleted(event.id))
                        } label: {
                            Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.largeTitle)
                                .foregroundStyle(event.isCompleted ? .green : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .strikethrough(event.isCompleted)
                            HStack(spacing: 6) {
                                Image(systemName: event.categoryIcon)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Text(event.category.capitalized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                    }
                }

                // Edit title
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Event title", text: Binding(
                            get: { event.title },
                            set: { store.send(.updateEventTitle(event.id, $0)) }
                        ))
                        .font(.subheadline)
                    }
                }

                // Category
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            eventCategoryChip("activity", icon: "figure.run")
                            eventCategoryChip("appointment", icon: "cross.case.fill")
                            eventCategoryChip("school", icon: "graduationcap.fill")
                            eventCategoryChip("meal", icon: "fork.knife")
                            eventCategoryChip("outing", icon: "car.fill")
                        }
                    }
                }

                // Date/Time
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date & Time")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.blue)
                            Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                            Spacer()
                            if event.date.isToday {
                                Text("TODAY")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                // Assigned to
                GlassCard {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.blue)
                        Text("Assigned: \(event.assignedTo.capitalized)")
                            .font(.subheadline)
                        Spacer()
                    }
                }

                // Delete
                Button(role: .destructive) {
                    store.send(.deleteEvent(event.id))
                    store.send(.selectEvent(nil))
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Event")
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
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func eventCategoryChip(_ key: String, icon: String) -> some View {
        Button {
            store.send(.updateEventCategory(event.id, key))
        } label: {
            Image(systemName: icon)
                .font(.caption)
                .padding(8)
                .background(event.category == key ? Color.blue.opacity(0.2) : Color(.systemGray5))
                .foregroundStyle(event.category == key ? .blue : .secondary)
                .clipShape(Circle())
        }
    }
}

#Preview {
    EventDetailView(
        store: Store(initialState: FamilyHQReducer.State()) {
            FamilyHQReducer()
        },
        event: FamilyHQReducer.State.EventState(
            id: UUID(),
            title: "Soccer Practice",
            category: "activity",
            date: Date(),
            isCompleted: false,
            assignedTo: "Dad"
        )
    )
}
