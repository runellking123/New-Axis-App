import ComposableArchitecture
import SwiftUI

struct InteractionLogView: View {
    @Bindable var store: StoreOf<SocialCircleReducer>

    private let interactionTypes = ["call", "text", "coffee", "meeting", "email", "facetime"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(interactionTypes, id: \.self) { type in
                                Button {
                                    store.send(.newInteractionTypeChanged(type))
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: iconFor(type))
                                            .font(.title3)
                                        Text(type.capitalized)
                                            .font(.caption2)
                                    }
                                    .frame(width: 60, height: 50)
                                    .background(store.newInteractionType == type ? Color.purple.opacity(0.15) : Color(.systemGray5))
                                    .foregroundStyle(store.newInteractionType == type ? .purple : .secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }

                Section("When") {
                    DatePicker("Date", selection: $store.newInteractionDate.sending(\.newInteractionDateChanged), displayedComponents: [.date, .hourAndMinute])
                }

                Section("Notes") {
                    TextField("What did you talk about?", text: $store.newInteractionNotes.sending(\.newInteractionNotesChanged), axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Interaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissInteractionLog) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { store.send(.logInteraction) }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func iconFor(_ type: String) -> String {
        switch type {
        case "call": return "phone.fill"
        case "text": return "message.fill"
        case "coffee": return "cup.and.saucer.fill"
        case "meeting": return "person.2.fill"
        case "email": return "envelope.fill"
        case "facetime": return "video.fill"
        default: return "bubble.left.fill"
        }
    }
}
