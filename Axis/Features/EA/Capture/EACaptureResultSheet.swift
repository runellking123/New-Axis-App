import SwiftUI

struct EACaptureResultSheet: View {
    let classification: AIExecutiveService.CaptureClassification
    let rawInput: String
    var onConfirm: () -> Void
    var onSendToInbox: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Classification badge
                VStack(spacing: 12) {
                    Image(systemName: typeIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(typeColor)

                    Text(classification.type.capitalized)
                        .font(.title2)
                        .fontWeight(.bold)

                    // Confidence indicator
                    HStack(spacing: 4) {
                        Text("Confidence:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int((classification.confidence ?? 0) * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(confidenceColor)
                    }
                }

                // Parsed fields
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        if let title = classification.parsedTitle {
                            LabeledContent("Title", value: title)
                                .font(.subheadline)
                        }
                        if let deadline = classification.parsedDeadline {
                            LabeledContent("Deadline") {
                                Text(deadline, style: .date)
                                    .font(.subheadline)
                            }
                        }
                        if let priority = classification.parsedPriority {
                            LabeledContent("Priority", value: priority.capitalized)
                                .font(.subheadline)
                        }
                    }
                } label: {
                    Text("Parsed Fields")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("Confirm")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.axisGold)

                    Button(action: onSendToInbox) {
                        Text("Send to Inbox")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Classify Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var typeIcon: String {
        switch classification.type {
        case "task": return "checklist"
        case "event": return "calendar"
        case "note": return "note.text"
        default: return "questionmark.circle"
        }
    }

    private var typeColor: Color {
        switch classification.type {
        case "task": return Color.axisGold
        case "event": return .purple
        case "note": return .blue
        default: return .gray
        }
    }

    private var confidenceColor: Color {
        let conf = classification.confidence ?? 0
        if conf >= 0.85 { return .green }
        if conf >= 0.6 { return .orange }
        return .red
    }
}

#Preview {
    EACaptureResultSheet(
        classification: AIExecutiveService.CaptureClassification(type: "task", confidence: 0.92, parsedTitle: "Finish budget report", parsedDeadline: nil, parsedPriority: "high"),
        rawInput: "Finish budget report by Friday",
        onConfirm: {},
        onSendToInbox: {},
        onDismiss: {}
    )
}
