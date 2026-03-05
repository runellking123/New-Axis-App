import SwiftUI

struct WorkSuitePlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.axisGold.opacity(0.5))

                VStack(spacing: 8) {
                    Text("Work Suite")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Dual workspaces for Wiley University\nand consulting projects.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "rectangle.split.2x1", title: "Dual Workspaces", subtitle: "Wiley + Consulting")
                    featureRow(icon: "list.bullet.rectangle", title: "Project Boards", subtitle: "Kanban-style tracking")
                    featureRow(icon: "person.2", title: "Team Pulse", subtitle: "Kanisha & Shneka at a glance")
                    featureRow(icon: "exclamationmark.triangle", title: "Deadline Engine", subtitle: "72h → 24h → 2h escalation")
                    featureRow(icon: "doc.text", title: "Document Vault", subtitle: "AI-tagged file storage")
                    featureRow(icon: "timer", title: "Focus Timer", subtitle: "Pomodoro with Dynamic Island")
                }
                .padding(.horizontal, 32)

                Spacer()

                Text("Coming in Phase 2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Work Suite")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.axisGold)
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.axisGold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
