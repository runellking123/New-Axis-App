import SwiftUI

struct EAQuickCaptureOverlay: View {
    @State private var isExpanded = false
    @State private var inputText = ""
    @State private var classification: AIExecutiveService.CaptureClassification?
    @State private var showResult = false
    @State private var showToast = false
    @State private var toastMessage = ""
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                if isExpanded {
                    expandedCapture
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                } else {
                    captureButton
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 90) // Above tab bar
        }
        .animation(.spring(duration: 0.3), value: isExpanded)
        .overlay(alignment: .top) {
            if showToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
        .animation(.spring(duration: 0.3), value: showToast)
        .sheet(isPresented: $showResult) {
            if let result = classification {
                EACaptureResultSheet(
                    classification: result,
                    rawInput: inputText,
                    onConfirm: { handleConfirm(result) },
                    onSendToInbox: { handleSendToInbox() },
                    onDismiss: {
                        showResult = false
                        classification = nil
                    }
                )
            }
        }
    }

    // MARK: - Capture Button

    private var captureButton: some View {
        Button {
            isExpanded = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.axisGold)
                .clipShape(Circle())
                .shadow(color: Color.axisGold.opacity(0.4), radius: 8, y: 4)
        }
    }

    // MARK: - Expanded Capture

    private var expandedCapture: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("Quick capture...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    // Voice - use existing SpeechService
                    let speech = SpeechService.shared
                    if speech.isRecording {
                        speech.stopRecording()
                        inputText = speech.transcribedText
                        submitCapture()
                    } else {
                        Task {
                            let authorized = await speech.requestAuthorization()
                            if authorized {
                                try? speech.startRecording()
                            }
                        }
                    }
                } label: {
                    Image(systemName: SpeechService.shared.isRecording ? "mic.fill" : "mic")
                        .font(.title3)
                        .foregroundStyle(SpeechService.shared.isRecording ? .red : Color.axisGold)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Button {
                    submitCapture()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inputText.isEmpty ? .gray : Color.axisGold)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    isExpanded = false
                    inputText = ""
                    classification = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 340)
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(toastMessage)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func submitCapture() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let result = AIExecutiveService.shared.classifyCapture(input: inputText)
        classification = result

        if result.confidence >= 0.85 {
            // Auto-create with toast
            handleConfirm(result)
        } else {
            // Show result sheet for manual triage
            showResult = true
        }
    }

    private func handleConfirm(_ result: AIExecutiveService.CaptureClassification) {
        let typeName: String
        switch result.type {
        case "task": typeName = "Task"
        case "event": typeName = "Event"
        default: typeName = "Note"
        }

        toastMessage = "\(typeName) created"
        showToast = true
        isExpanded = false
        inputText = ""
        classification = nil
        showResult = false

        Task {
            try? await Task.sleep(for: .seconds(2))
            showToast = false
        }
    }

    private func handleSendToInbox() {
        toastMessage = "Sent to inbox"
        showToast = true
        isExpanded = false
        inputText = ""
        classification = nil
        showResult = false

        Task {
            try? await Task.sleep(for: .seconds(2))
            showToast = false
        }
    }
}
