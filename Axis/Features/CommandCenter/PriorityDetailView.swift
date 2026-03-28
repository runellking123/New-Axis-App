import ComposableArchitecture
import SwiftUI

struct PriorityDetailView: View {
    @Bindable var store: StoreOf<CommandCenterReducer>
    let priority: CommandCenterReducer.State.PriorityState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status card
                GlassCard {
                    HStack(spacing: 16) {
                        Button {
                            store.send(.togglePriority(priority.id))
                        } label: {
                            Image(systemName: priority.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.largeTitle)
                                .foregroundStyle(priority.isCompleted ? .green : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(priority.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .strikethrough(priority.isCompleted)
                            Text(priority.isCompleted ? "Completed" : "In Progress")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(priority.isCompleted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .foregroundStyle(priority.isCompleted ? .green : .orange)
                                .clipShape(Capsule())
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
                        TextField("Priority title", text: Binding(
                            get: { priority.title },
                            set: { store.send(.updatePriorityTitle(priority.id, $0)) }
                        ))
                        .font(.subheadline)
                    }
                }

                // Module
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            Image(systemName: priority.sourceIcon)
                                .foregroundStyle(Color.axisGold)
                            Text(moduleLabel(priority.sourceModule))
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }

                // Time estimate
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Estimate")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 12) {
                            ForEach([15, 30, 45, 60, 120], id: \.self) { mins in
                                Button {
                                    store.send(.updatePriorityTimeEstimate(priority.id, mins))
                                } label: {
                                    Text(mins < 60 ? "\(mins)m" : "\(mins/60)h")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            priority.timeEstimate == formatTime(mins)
                                                ? Color.axisGold.opacity(0.2)
                                                : Color(.systemGray5)
                                        )
                                        .foregroundStyle(
                                            priority.timeEstimate == formatTime(mins)
                                                ? Color.axisGold
                                                : .secondary
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                // Context mode
                GlassCard {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(Color.axisGold)
                        Text("Context: \(priority.contextMode.capitalized)")
                            .font(.subheadline)
                        Spacer()
                    }
                }

                // Delete
                Button(role: .destructive) {
                    store.send(.deletePriority(priority.id))
                    store.send(.selectPriority(nil))
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Priority")
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
        .navigationTitle("Priority")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func moduleLabel(_ module: String) -> String {
        switch module {
        case "commandCenter": return "Command Center"
        case "workSuite": return "Work Suite"
        case "familyHQ": return "Family HQ"
        case "socialCircle": return "Social Circle"
        case "explore": return "Explore"
        case "balance": return "Balance"
        default: return module.capitalized
        }
    }

    private func formatTime(_ mins: Int) -> String {
        if mins < 60 {
            return "\(mins) min"
        } else {
            let h = mins / 60
            let m = mins % 60
            return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
        }
    }
}


#Preview {
    PriorityDetailView(
        store: Store(initialState: CommandCenterReducer.State()) {
            CommandCenterReducer()
        },
        priority: CommandCenterReducer.State.PriorityState(
            id: UUID(),
            title: "Review Q2 budget",
            sourceModule: "workSuite",
            sourceIcon: "building.columns.fill",
            timeEstimate: "30 min",
            isCompleted: false,
            contextMode: "work"
        )
    )
}
