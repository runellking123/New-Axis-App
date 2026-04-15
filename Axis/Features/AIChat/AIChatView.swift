import ComposableArchitecture
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - AIChatView

struct AIChatView: View {
    @Bindable var store: StoreOf<AIChatReducer>

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var streamingElapsed: TimeInterval = 0
    @State private var streamingTimer: Timer?
    @State private var threadSearchText: String = ""
    @State private var editingMessageId: UUID?
    @State private var editingText: String = ""
    @State private var speechService = SpeechService.shared
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                quickActionChips

                if store.messages.isEmpty && !store.isStreaming {
                    emptyState
                } else {
                    messageList
                }

                if !store.suggestedFollowUps.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.suggestedFollowUps, id: \.self) { suggestion in
                                Button { store.send(.tappedFollowUp(suggestion)) } label: {
                                    Text(suggestion)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.axisGold.opacity(0.12))
                                        .foregroundStyle(Color.axisGold)
                                        .clipShape(.capsule)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 36)
                }

                if hasAttachments {
                    attachmentPreviewBar
                }

                inputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button { store.send(.toggleModelPicker) } label: {
                        VStack(spacing: 0) {
                            Text("AXIS")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(Color.axisGold)
                            Text(store.selectedModelName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.send(.toggleThreadList) } label: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(Color.axisGold)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { store.send(.createNewThread) } label: {
                            Label("New Chat", systemImage: "square.and.pencil")
                        }
                        Button { exportChatToPDF() } label: {
                            Label("Export PDF", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Color.axisGold)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showThreadList },
                set: { newValue in
                    if !newValue { store.send(.dismissThreadList) }
                }
            )) {
                threadListSheet
            }
            .sheet(isPresented: Binding(
                get: { store.showModelPicker },
                set: { newValue in
                    if !newValue { store.send(.dismissModelPicker) }
                }
            )) {
                modelPickerSheet
            }
            .confirmationDialog("Add Attachment", isPresented: Binding(
                get: { store.showAttachmentMenu },
                set: { newValue in
                    if !newValue { store.send(.dismissAttachmentMenu) }
                }
            )) {
                Button {
                    store.send(.toggleImagePicker)
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }
                Button {
                    store.send(.toggleCamera)
                } label: {
                    Label("Camera", systemImage: "camera")
                }
                Button {
                    store.send(.toggleFilePicker)
                } label: {
                    Label("Files", systemImage: "doc")
                }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(
                isPresented: Binding(
                    get: { store.showImagePicker },
                    set: { newValue in
                        if !newValue { store.send(.dismissImagePicker) }
                    }
                ),
                selection: $selectedPhotoItems,
                maxSelectionCount: 5,
                matching: .images
            )
            .onChange(of: selectedPhotoItems) { _, newItems in
                for item in newItems {
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            store.send(.addImage(data))
                        }
                    }
                }
                selectedPhotoItems = []
            }
            .fileImporter(
                isPresented: Binding(
                    get: { store.showFilePicker },
                    set: { newValue in
                        if !newValue { store.send(.dismissFilePicker) }
                    }
                ),
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        guard url.startAccessingSecurityScopedResource() else { continue }
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url) {
                            store.send(.addFile(url.lastPathComponent, data))
                        }
                    }
                case .failure:
                    break
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: Binding(
                get: { store.showCamera },
                set: { _ in }
            )) {
                CameraPickerView(
                    onCapture: { imageData in
                        store.send(.addImage(imageData))
                    },
                    onDismiss: {
                        if store.showCamera {
                            store.send(.toggleCamera)
                        }
                    }
                )
                .ignoresSafeArea()
            }
            #endif
            .onAppear { store.send(.onAppear) }
            .onChange(of: store.isStreaming) { _, isStreaming in
                if isStreaming {
                    streamingElapsed = 0
                    streamingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        streamingElapsed += 1
                    }
                } else {
                    streamingTimer?.invalidate()
                    streamingTimer = nil
                    streamingElapsed = 0
                }
            }
        }
    }

    // MARK: - Computed Helpers

    private var hasAttachments: Bool {
        !store.attachedImages.isEmpty || !store.attachedFileNames.isEmpty
    }

    private var totalAttachmentCount: Int {
        store.attachedImages.count + store.attachedFileNames.count
    }

    private var canSend: Bool {
        !store.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Export

    private func exportChatToPDF() {
        guard !store.messages.isEmpty else { return }
        var text = "AXIS AI Chat Export\n"
        text += "Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))\n"
        text += String(repeating: "\u{2500}", count: 40) + "\n\n"
        for msg in store.messages {
            let role = msg.role == "user" ? "You" : "AXIS"
            text += "[\(role)]\n\(msg.content)\n\n"
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("AXIS_Chat_Export.txt")
        try? text.write(to: tempURL, atomically: true, encoding: .utf8)
        PlatformServices.share(items: [tempURL])
    }

    // MARK: - Quick Action Chips

    private var quickActionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton("My Day", icon: "calendar", prompt: "Give me a quick summary of my day — schedule, priorities, and any deadlines.")
                chipButton("Morning Brief", icon: "newspaper", prompt: "Generate my executive morning briefing.")
                chipButton("Compose", icon: "envelope", prompt: "Help me compose a professional message.")
                chipButton("Data Report", icon: "chart.bar", prompt: "Help me structure a data analysis report.")
                chipButton("Prep Notes", icon: "person.3", prompt: "Help me prepare talking points for my next meeting.")
                chipButton("Compliance", icon: "building.columns", prompt: "Help me with accreditation and compliance requirements.")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func chipButton(_ title: String, icon: String, prompt: String) -> some View {
        Button {
            store.send(.quickAction(prompt))
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(Color.axisGold)
            .background(Color.axisGold.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.axisGold, Color.axisGold.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    Text("How can I help you, Dr. King?")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Ask me anything or tap a quick action below")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !store.isConfigured {
                    apiKeyWarning
                }

                emptyStateQuickActionGrid

                Spacer()
            }
            .padding()
        }
    }

    private var apiKeyWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Add your API key in Settings to start chatting")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyStateQuickActionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            gridActionButton("My Day", icon: "calendar", color: .blue, prompt: "Give me a quick summary of my day — schedule, priorities, and any deadlines.")
            gridActionButton("Morning Brief", icon: "newspaper", color: .purple, prompt: "Generate my executive morning briefing.")
            gridActionButton("Compose", icon: "envelope", color: .orange, prompt: "Help me compose a professional message.")
            gridActionButton("Data Report", icon: "chart.bar", color: .green, prompt: "Help me structure a data analysis report.")
            gridActionButton("Prep Notes", icon: "person.3", color: .cyan, prompt: "Help me prepare talking points for my next meeting.")
            gridActionButton("Compliance", icon: "building.columns", color: .red, prompt: "Help me with accreditation and compliance requirements.")
        }
    }

    private func gridActionButton(_ title: String, icon: String, color: Color, prompt: String) -> some View {
        Button { store.send(.quickAction(prompt)) } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(store.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                        // Show action confirmations after the assistant message that triggered them
                        if msg.role == "assistant" {
                            let actionsForMsg = store.executedActions.filter { $0.messageId == msg.id }
                            if !actionsForMsg.isEmpty {
                                ForEach(actionsForMsg) { action in
                                    actionConfirmationCard(action)
                                }
                            }
                        }
                    }
                    if store.isStreaming {
                        streamingBubble
                            .id("streaming")
                    }
                    if let error = store.error {
                        errorBubble(error)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onTapGesture {
                isInputFocused = false
            }
            .onChange(of: store.messages.count) {
                if let last = store.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: store.streamingContent) {
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ msg: AIChatReducer.State.MessageState) -> some View {
        HStack(alignment: .bottom) {
            if msg.role == "user" { Spacer(minLength: 48) }

            VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 6) {
                // Model badge (assistant only)
                if msg.role == "assistant" && !msg.model.isEmpty {
                    modelBadge(msg.model)
                }

                // Message bubble
                VStack(alignment: .leading, spacing: AxisSpacing.xs) {
                    Text(msg.content)
                        .font(.body)
                        .textSelection(.enabled)

                    // Attachment count badge
                    if msg.hasAttachments {
                        HStack(spacing: AxisSpacing.xs) {
                            Image(systemName: "paperclip")
                                .font(.caption2)
                            Text("\(msg.attachmentCount) attachment\(msg.attachmentCount == 1 ? "" : "s")")
                                .font(.caption2)
                        }
                        .foregroundStyle(msg.role == "user" ? Color.black.opacity(0.7) : .secondary)
                    }
                }
                .padding(.horizontal, AxisSpacing.lg)
                .padding(.vertical, AxisSpacing.md)
                .background {
                    if msg.role == "user" {
                        RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous)
                            .fill(AxisTheme.goldGradient)
                    } else {
                        RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous)
                                    .strokeBorder(Color.axisDivider, lineWidth: 1)
                            )
                    }
                }
                .foregroundStyle(msg.role == "user" ? Color.black : .primary)
                .contextMenu {
                    contextMenuItems(for: msg)
                }

                // Bottom row: timestamp + action buttons
                HStack(spacing: 12) {
                    Text(msg.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if msg.role == "assistant" {
                        Button {
                            PlatformServices.copyToClipboard(msg.content)
                            store.send(.copyMessage(msg.content))
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.send(.regenerateLastResponse)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: msg.role == "user" ? .trailing : .leading)

            if msg.role == "assistant" { Spacer(minLength: 48) }
        }
    }

    private func modelBadge(_ modelName: String) -> some View {
        Text(modelName)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
    }

    private func actionConfirmationCard(_ action: AIChatReducer.State.ExecutedAction) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: action.icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 32, height: 32)
                .background(.green.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("\(action.type.capitalized) Created")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
                Text(action.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !action.details.isEmpty {
                    Text(action.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.green.opacity(0.2), lineWidth: 1)
        )
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func contextMenuItems(for msg: AIChatReducer.State.MessageState) -> some View {
        Button {
            PlatformServices.copyToClipboard(msg.content)
            store.send(.copyMessage(msg.content))
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        Button {
            shareText(msg.content)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Button {
            sendViaOutlook(subject: "From AXIS", body: msg.content)
        } label: {
            Label("Send as Email", systemImage: "envelope.fill")
        }

        if msg.role == "user" {
            Button {
                editingMessageId = msg.id
                editingText = msg.content
                store.send(.editAndResend(msg.id, msg.content))
            } label: {
                Label("Edit & Resend", systemImage: "pencil")
            }
        }

        if msg.role == "assistant" {
            Button {
                store.send(.regenerateLastResponse)
            } label: {
                Label("Regenerate", systemImage: "arrow.counterclockwise")
            }
        }
    }

    private func sendViaOutlook(subject: String, body: String, to: String = "") {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedTo = to.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        #if os(iOS)
        let outlookURL = "ms-outlook://compose?to=\(encodedTo)&subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: outlookURL), UIApplication.shared.canOpenURL(url) {
            PlatformServices.openURL(url)
        } else {
            let mailtoURL = "mailto:\(encodedTo)?subject=\(encodedSubject)&body=\(encodedBody)"
            if let url = URL(string: mailtoURL) {
                PlatformServices.openURL(url)
            }
        }
        #else
        let mailtoURL = "mailto:\(encodedTo)?subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: mailtoURL) {
            PlatformServices.openURL(url)
        }
        #endif
    }

    private func shareText(_ text: String) {
        PlatformServices.share(items: [text])
    }

    // MARK: - Streaming Bubble

    private var streamingBubble: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                modelBadge(MultiProviderChatService.shared.selectedModel.displayName)

                if store.streamingContent.isEmpty {
                    HStack(spacing: 6) {
                        TypingDotsView()
                        Text("Thinking... \(Int(streamingElapsed))s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.streamingContent)
                            .font(.subheadline)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text("\(Int(streamingElapsed))s")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .frame(maxWidth: 300, alignment: .leading)
            Spacer(minLength: 48)
        }
    }

    // MARK: - Error Bubble

    private func errorBubble(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
            Button("Dismiss") {
                store.send(.dismissError)
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .background(.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Attachment Preview Bar

    private var attachmentPreviewBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                Text("\(totalAttachmentCount) attachment\(totalAttachmentCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 16)

                Spacer()

                Button {
                    store.send(.clearAttachments)
                } label: {
                    Text("Clear All")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Image attachments
                    ForEach(Array(store.attachedImages.enumerated()), id: \.offset) { index, imageData in
                        attachmentImageThumbnail(data: imageData, index: index)
                    }
                    // File attachments
                    ForEach(Array(store.attachedFileNames.enumerated()), id: \.offset) { index, fileName in
                        attachmentFileThumbnail(
                            name: fileName,
                            index: store.attachedImages.count + index
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
        .background(.bar)
    }

    private func attachmentImageThumbnail(data: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            #if os(iOS)
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            #elseif os(macOS)
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.windowBackgroundColor))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            #endif

            removeButton(index: index)
        }
    }

    private func attachmentFileThumbnail(name: String, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 2) {
                Image(systemName: "doc.fill")
                    .font(.title3)
                    .foregroundStyle(Color.axisGold)
                Text(name)
                    .font(.system(size: 8))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 56)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            removeButton(index: index)
        }
    }

    private func removeButton(index: Int) -> some View {
        Button {
            store.send(.removeAttachment(index))
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .background(Circle().fill(.black.opacity(0.6)))
        }
        .offset(x: 4, y: -4)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                // Attachment button
                Button {
                    store.send(.toggleAttachmentMenu)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.axisGold)
                }
                .buttonStyle(.plain)

                // Text field
                TextField("Ask AXIS anything...", text: $store.inputText.sending(\.inputTextChanged), axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(1...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .submitLabel(.done)

                // Mic button — real speech-to-text via SpeechService
                Button {
                    if speechService.isRecording {
                        speechService.stopRecording()
                        // Append transcribed text to input after a brief delay for finalization
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            let text = speechService.transcribedText
                            if !text.isEmpty {
                                let current = store.inputText
                                let newText = current.isEmpty ? text : current + " " + text
                                store.send(.inputTextChanged(newText))
                            }
                        }
                    } else {
                        Task {
                            let authorized = await speechService.requestAuthorization()
                            if authorized {
                                try? speechService.startRecording()
                            }
                        }
                    }
                } label: {
                    Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                        .font(.title3)
                        .foregroundStyle(speechService.isRecording ? Color.red : .secondary)
                        .symbolEffect(.pulse, isActive: speechService.isRecording)
                }
                .buttonStyle(.plain)

                // Send / Stop button
                Button {
                    store.send(.sendMessage)
                } label: {
                    Image(systemName: store.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            canSend || store.isStreaming
                                ? Color.axisGold
                                : Color.gray.opacity(0.4)
                        )
                }
                .disabled(!canSend && !store.isStreaming)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    // MARK: - Thread List Sheet

    private var threadListSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search conversations...", text: $threadSearchText)
                        .font(.subheadline)
                }
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 8)

                // Thread count
                Text("\(filteredThreads.count) conversation\(filteredThreads.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)

                List {
                    Button {
                        store.send(.createNewThread)
                    } label: {
                        Label("New Chat", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.axisGold)
                    }

                    ForEach(filteredThreads) { thread in
                        Button {
                            store.send(.selectThread(thread.id))
                        } label: {
                            HStack {
                                Image(systemName: "pin.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.axisGold.opacity(0.5))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(thread.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(thread.updatedAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if thread.id == store.selectedThreadId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.axisGold)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.send(.deleteThread(thread.id))
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }

                    Section {
                        Button("Clear All Conversations", role: .destructive) {
                            store.send(.clearAllThreads)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.send(.dismissThreadList) }
                        .foregroundStyle(Color.axisGold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var filteredThreads: [AIChatReducer.State.ThreadState] {
        if threadSearchText.isEmpty {
            return store.threads
        }
        return store.threads.filter {
            $0.title.localizedCaseInsensitiveContains(threadSearchText)
        }
    }

    // MARK: - Model Picker Sheet

    private var modelPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(AIModelProvider.allCases) { provider in
                    Section {
                        ForEach(AIModel.allModels.filter { $0.provider == provider }) { model in
                            Button {
                                store.send(.modelSelected(model.id))
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Text(model.id)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if model.id == MultiProviderChatService.shared.selectedModelId {
                                        Text("Active")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.axisGold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.axisGold.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            providerIcon(for: provider)
                                .font(.caption)
                                .foregroundStyle(Color.axisGold)
                            Text(provider.rawValue)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.send(.dismissModelPicker) }
                        .foregroundStyle(Color.axisGold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func providerIcon(for provider: AIModelProvider) -> Image {
        switch provider {
        case .claude:
            return Image(systemName: "brain.head.profile")
        }
    }
}

// MARK: - Typing Dots Animation

private struct TypingDotsView: View {
    @State private var phase: Int = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.axisGold)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == index ? 1.3 : 0.7)
                    .opacity(phase == index ? 1.0 : 0.4)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Camera Picker

#if os(iOS)
struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                parent.onCapture(data)
            }
            parent.onDismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
        }
    }
}
#endif

#Preview {
    AIChatView(
        store: Store(initialState: AIChatReducer.State()) {
            AIChatReducer()
        }
    )
}
