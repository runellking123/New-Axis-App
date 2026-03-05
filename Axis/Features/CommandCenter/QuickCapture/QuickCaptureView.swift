import SwiftUI

struct QuickCaptureView: View {
    let onDismiss: () -> Void

    @State private var captureText = ""
    @State private var isRecordingVoice = false
    @State private var classifiedModule = "commandCenter"
    @State private var showClassification = false

    private let speechService = SpeechService.shared
    private let aiService = AIService.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                // Header
                HStack {
                    Text("Quick Capture")
                        .font(.headline)
                    Spacer()
                    Button("Done", action: saveAndDismiss)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.axisGold)
                }
                .padding(.horizontal)

                // Text input
                TextEditor(text: $captureText)
                    .frame(height: 100)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .onChange(of: captureText) { _, newValue in
                        if newValue.count > 10 {
                            classifiedModule = aiService.classifyNote(newValue)
                            showClassification = true
                        }
                    }

                // Voice recording button
                HStack(spacing: 20) {
                    Button {
                        toggleVoiceRecording()
                    } label: {
                        HStack {
                            Image(systemName: isRecordingVoice ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                            Text(isRecordingVoice ? "Stop" : "Voice")
                                .font(.subheadline)
                        }
                        .foregroundStyle(isRecordingVoice ? .red : Color.axisGold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }

                    // Classification badge
                    if showClassification {
                        HStack(spacing: 4) {
                            Image(systemName: moduleIcon(classifiedModule))
                                .font(.caption)
                            Text(moduleLabel(classifiedModule))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.axisGold.opacity(0.15))
                        .foregroundStyle(Color.axisGold)
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
                .animation(.spring(duration: 0.3), value: showClassification)
            }
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 20, y: -5)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
        )
    }

    private func toggleVoiceRecording() {
        if isRecordingVoice {
            speechService.stopRecording()
            captureText = speechService.transcribedText
            isRecordingVoice = false
        } else {
            Task {
                let authorized = await speechService.requestAuthorization()
                if authorized {
                    try? speechService.startRecording()
                    isRecordingVoice = true
                }
            }
        }
    }

    private func saveAndDismiss() {
        guard !captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            onDismiss()
            return
        }
        let persistence = PersistenceService.shared

        // Save as captured note
        let note = CapturedNote(
            content: captureText,
            transcribedFromVoice: isRecordingVoice,
            classifiedModule: classifiedModule
        )
        persistence.saveCapturedNote(note)

        // Also create a priority item so it shows on Command Center
        let existingCount = persistence.fetchPriorityItems().count
        let item = PriorityItem(
            title: captureText.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceModule: classifiedModule,
            timeEstimateMinutes: 30,
            sortOrder: existingCount
        )
        persistence.savePriorityItem(item)

        HapticService.notification(.success)
        onDismiss()
    }

    private func moduleIcon(_ module: String) -> String {
        switch module {
        case "workSuite": return "building.columns.fill"
        case "familyHQ": return "house.fill"
        case "socialCircle": return "person.2.fill"
        case "explore": return "safari.fill"
        case "balance": return "heart.fill"
        default: return "bolt.fill"
        }
    }

    private func moduleLabel(_ module: String) -> String {
        switch module {
        case "workSuite": return "Work"
        case "familyHQ": return "Family"
        case "socialCircle": return "Social"
        case "explore": return "Explore"
        case "balance": return "Balance"
        default: return "Command"
        }
    }
}
