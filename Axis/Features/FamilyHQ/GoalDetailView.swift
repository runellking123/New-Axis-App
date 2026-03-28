import ComposableArchitecture
import SwiftUI

struct GoalDetailView: View {
    @Bindable var store: StoreOf<FamilyHQReducer>
    let goal: FamilyHQReducer.State.GoalState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Progress header
                GlassCard {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: goal.categoryIcon)
                                .font(.title2)
                                .foregroundStyle(categoryColor(goal.category))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.title)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                HStack(spacing: 6) {
                                    Text(goal.category.capitalized)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(categoryColor(goal.category).opacity(0.15))
                                        .foregroundStyle(categoryColor(goal.category))
                                        .clipShape(Capsule())
                                    if goal.isCompleted {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            Spacer()
                        }

                        // Progress bar
                        if !goal.milestones.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 12)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(goal.isCompleted ? Color.green : categoryColor(goal.category))
                                            .frame(width: geometry.size.width * goal.progress, height: 12)
                                    }
                                }
                                .frame(height: 12)

                                Text("\(goal.completedMilestoneCount) of \(goal.milestones.count) milestones (\(Int(goal.progress * 100))%)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Edit title
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Goal title", text: Binding(
                            get: { goal.title },
                            set: { store.send(.updateGoalTitle(goal.id, $0)) }
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
                            goalCategoryChip("family", icon: "house.fill", color: .blue)
                            goalCategoryChip("career", icon: "briefcase.fill", color: .orange)
                            goalCategoryChip("health", icon: "heart.fill", color: .green)
                            goalCategoryChip("personal", icon: "person.fill", color: .purple)
                            goalCategoryChip("financial", icon: "dollarsign.circle.fill", color: .yellow)
                        }
                    }
                }

                // Target date
                if let targetDate = goal.targetDate {
                    GlassCard {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(targetDate < Date() && !goal.isCompleted ? .red : .blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Target Date")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(targetDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            if targetDate < Date() && !goal.isCompleted {
                                Text("OVERDUE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                // Milestones
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Milestones")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Button {
                                store.send(.addMilestoneToGoal(goal.id))
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.callout)
                                    .foregroundStyle(.blue)
                            }
                        }

                        if goal.milestones.isEmpty {
                            Text("No milestones yet. Tap + to add one.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(goal.milestones.sorted { $0.sortOrder < $1.sortOrder }) { ms in
                                HStack(spacing: 10) {
                                    Button {
                                        store.send(.toggleMilestone(goalId: goal.id, milestoneId: ms.id))
                                    } label: {
                                        Image(systemName: ms.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .font(.callout)
                                            .foregroundStyle(ms.isCompleted ? .green : .secondary)
                                    }

                                    Text(ms.title)
                                        .font(.subheadline)
                                        .strikethrough(ms.isCompleted)
                                        .foregroundStyle(ms.isCompleted ? .secondary : .primary)

                                    Spacer()

                                    Button {
                                        store.send(.removeMilestoneFromGoal(goalId: goal.id, milestoneId: ms.id))
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .font(.caption)
                                            .foregroundStyle(.red.opacity(0.6))
                                    }
                                }
                            }
                        }
                    }
                }

                // Notes
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Add notes...", text: Binding(
                            get: { goal.notes },
                            set: { store.send(.updateGoalNotes(goal.id, $0)) }
                        ), axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(3...8)
                    }
                }

                // Delete
                Button(role: .destructive) {
                    store.send(.deleteGoal(goal.id))
                    store.send(.selectGoal(nil))
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Goal")
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
        .navigationTitle("Goal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func goalCategoryChip(_ key: String, icon: String, color: Color) -> some View {
        Button {
            store.send(.updateGoalCategory(goal.id, key))
        } label: {
            Image(systemName: icon)
                .font(.caption)
                .padding(8)
                .background(goal.category == key ? color.opacity(0.2) : Color(.systemGray5))
                .foregroundStyle(goal.category == key ? color : .secondary)
                .clipShape(Circle())
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "family": return .blue
        case "career": return .orange
        case "health": return .green
        case "personal": return .purple
        case "financial": return .yellow
        default: return .gray
        }
    }
}

#Preview {
    GoalDetailView(
        store: Store(initialState: FamilyHQReducer.State()) {
            FamilyHQReducer()
        },
        goal: FamilyHQReducer.State.GoalState(
            id: UUID(),
            title: "Family Vacation",
            category: "travel",
            targetDate: Date().addingTimeInterval(86400 * 90),
            milestones: [],
            notes: "Plan trip to beach",
            createdAt: Date()
        )
    )
}
