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
                if store.messages.isEmpty && !store.isStreaming {
                    quickActionChips
                }

                if store.messages.isEmpty && !store.isStreaming {
                    emptyState
                } else {
                    messageList
                }

                if !store.suggestedFollowUps.isEmpty {
                    followUpChips
                }

                if hasAttachments {
                    attachmentPreviewBar
                }

                inputBar
            }
            .background(chatBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button { store.send(.toggleModelPicker) } label: {
                        VStack(spacing: 0) {
                            Text("AXIS")
                                .font(.system(.headline, design: .serif).weight(.bold))
                                .foregroundStyle(Color.axisAccent)
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

    // MARK: - Background

    private var chatBackground: some View {
        ZStack {
            Color.axisBackground
            TimeOfDay.current().skyGradient
                .opacity(0.55)
        }
        .ignoresSafeArea()
    }

    // MARK: - Follow-up Chips

    private var followUpChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AxisSpacing.sm) {
                ForEach(store.suggestedFollowUps, id: \.self) { suggestion in
                    Button { store.send(.tappedFollowUp(suggestion)) } label: {
                        HStack(spacing: AxisSpacing.xs) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption2)
                            Text(suggestion)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, AxisSpacing.md)
                        .padding(.vertical, AxisSpacing.xs + 2)
                        .foregroundStyle(Color.axisAccent)
                        .background(
                            Capsule().fill(Color.axisAccent.opacity(0.10))
                        )
                        .overlay(
                            Capsule().strokeBorder(Color.axisAccent.opacity(0.22), lineWidth: 0.5)
                        )
                        .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AxisSpacing.lg)
            .padding(.vertical, AxisSpacing.sm)
        }
    }

    // MARK: - Quick Action Chips

    private var quickActionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AxisSpacing.sm) {
                chipButton("Plan my day", icon: "sun.max", run: { store.send(.quickAction("Plan my day based on today's calendar, overdue reminders, and priorities. Be concise.")) })
                chipButton("Today", icon: "calendar", run: { store.send(.quickAction("Summarize my calendar and open reminders for today.")) })
                chipButton("Recap memos", icon: "waveform", run: { store.send(.quickAction("Summarize my most recent voice memos and extract action items as reminders.")) })
                chipButton("Add reminder…", icon: "checkmark.circle", run: { store.send(.prefillInput("Add a reminder for ")); isInputFocused = true })
                chipButton("Schedule…", icon: "calendar.badge.plus", run: { store.send(.prefillInput("Schedule a meeting on ")); isInputFocused = true })
                chipButton("Draft email…", icon: "envelope", run: { store.send(.prefillInput("Draft a professional email to ")); isInputFocused = true })
            }
            .padding(.horizontal, AxisSpacing.lg)
            .padding(.vertical, AxisSpacing.sm)
        }
    }

    private func chipButton(_ title: String, icon: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: AxisSpacing.xs) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, AxisSpacing.md)
            .padding(.vertical, AxisSpacing.xs + 2)
            .foregroundStyle(Color.axisInkSoft)
            .background(
                Capsule().fill(Color.axisPaper.opacity(0.85))
            )
            .overlay(
                Capsule().strokeBorder(Color.axisHairline, lineWidth: 0.5)
            )
            .shadow(color: AxisTheme.cardShadow, radius: 4, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        let tod = TimeOfDay.current()
        let displayName = store.userName.isEmpty ? "there" : store.userName

        return ScrollView {
            VStack(spacing: AxisSpacing.xl) {
                Spacer().frame(height: AxisSpacing.xxxl)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.axisGold.opacity(0.25), Color.axisGold.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.axisGold, Color.axisGoldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse, options: .repeating.speed(0.4))
                }

                VStack(spacing: AxisSpacing.sm) {
                    Text("\(tod.greeting), \(displayName)")
                        .font(.axisScreenTitle)
                        .foregroundStyle(Color.axisInk)
                        .multilineTextAlignment(.center)
                    Text("Ask me anything or tap a quick action below")
                        .font(.axisSubheadline)
                        .foregroundStyle(Color.axisInkMute)
                        .multilineTextAlignment(.center)
                }

                if !store.isConfigured {
                    apiKeyWarning
                }

                emptyStateQuickActionGrid

                Spacer()
            }
            .padding(AxisSpacing.lg)
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AxisSpacing.sm) {
            gridActionButton("Plan my day", icon: "sun.max", color: .axisOrangeTone, softColor: .axisOrangeSoft, prompt: "Plan my day based on today's calendar, overdue reminders, and priorities. Be concise.")
            gridActionButton("What's today?", icon: "calendar", color: .axisCobalt, softColor: .axisCobaltSoft, prompt: "Summarize my calendar and open reminders for today.")
            gridActionButton("Add reminder", icon: "checkmark.circle", color: .axisGreenTone, softColor: .axisGreenSoft, prompt: "Add a reminder for ")
            gridActionButton("Schedule meeting", icon: "calendar.badge.plus", color: .axisPurpleTone, softColor: .axisPurpleSoft, prompt: "Schedule a meeting on ")
            gridActionButton("Recap memos", icon: "waveform", color: .axisTealTone, softColor: .axisTealSoft, prompt: "Summarize my most recent voice memos and extract action items as reminders.")
            gridActionButton("Draft email", icon: "envelope", color: .axisYellowTone, softColor: .axisYellowSoft, prompt: "Draft a professional email to ")
        }
    }

    private func gridActionButton(_ title: String, icon: String, color: Color, softColor: Color, prompt: String) -> some View {
        Button {
            if prompt.hasSuffix(" ") {
                store.send(.prefillInput(prompt))
                isInputFocused = true
            } else {
                store.send(.quickAction(prompt))
            }
        } label: {
            VStack(spacing: AxisSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(softColor)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.axisInk)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AxisSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous)
                    .fill(Color.axisPaper.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous)
                    .strokeBorder(Color.axisHairline, lineWidth: 0.5)
            )
            .shadow(color: AxisTheme.cardShadow, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AxisSpacing.lg) {
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
                .padding(.horizontal, AxisSpacing.lg)
                .padding(.vertical, AxisSpacing.sm)
            }
            .scrollDismissesKeyboard(.immediately)
            .defaultScrollAnchor(.bottom)
            .onTapGesture {
                isInputFocused = false
            }
            .simultaneousGesture(
                // A downward drag anywhere on the chat transcript also dismisses
                // the keyboard — matches the native Messages app feel.
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if value.translation.height > 30 {
                            isInputFocused = false
                        }
                    }
            )
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
        HStack(alignment: .bottom, spacing: AxisSpacing.sm) {
            if msg.role == "user" {
                Spacer(minLength: 56)
            } else {
                AssistantAvatarView()
            }

            VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: AxisSpacing.xs) {
                if msg.role == "assistant" && !msg.model.isEmpty {
                    modelBadge(msg.model)
                }

                VStack(alignment: .leading, spacing: AxisSpacing.xs) {
                    Text(msg.content)
                        .font(.axisBodyDynamic)
                        .textSelection(.enabled)

                    if msg.hasAttachments {
                        HStack(spacing: AxisSpacing.xs) {
                            Image(systemName: "paperclip")
                                .font(.caption2)
                            Text("\(msg.attachmentCount) attachment\(msg.attachmentCount == 1 ? "" : "s")")
                                .font(.caption2)
                        }
                        .foregroundStyle(msg.role == "user" ? Color.black.opacity(0.65) : Color.axisInkMute)
                    }
                }
                .padding(.horizontal, AxisSpacing.lg)
                .padding(.vertical, AxisSpacing.md)
                .background {
                    if msg.role == "user" {
                        ChatBubbleShape(isUser: true)
                            .fill(AxisTheme.goldGradient)
                            .shadow(color: Color.axisGold.opacity(0.25), radius: 8, y: 3)
                    } else {
                        ChatBubbleShape(isUser: false)
                            .fill(Color.axisPaper.opacity(0.95))
                            .overlay(
                                ChatBubbleShape(isUser: false)
                                    .strokeBorder(Color.axisHairline, lineWidth: 0.5)
                            )
                            .shadow(color: AxisTheme.cardShadow, radius: 6, y: 2)
                    }
                }
                .foregroundStyle(msg.role == "user" ? Color.black.opacity(0.85) : Color.axisInk)
                .contextMenu {
                    contextMenuItems(for: msg)
                }

                HStack(spacing: AxisSpacing.md) {
                    Text(msg.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(Color.axisInkFaint)

                    if msg.role == "assistant" {
                        Button {
                            PlatformServices.copyToClipboard(msg.content)
                            store.send(.copyMessage(msg.content))
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(Color.axisInkFaint)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.send(.regenerateLastResponse)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                                .foregroundStyle(Color.axisInkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 320, alignment: msg.role == "user" ? .trailing : .leading)

            if msg.role == "assistant" {
                Spacer(minLength: 24)
            }
        }
    }

    private func modelBadge(_ modelName: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(.system(size: 8, weight: .bold))
            Text(modelName)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(Color.axisInkMute)
        .padding(.horizontal, AxisSpacing.sm)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Color.axisPaper.opacity(0.8))
        )
        .overlay(
            Capsule().strokeBorder(Color.axisHairline, lineWidth: 0.5)
        )
    }

    private func actionConfirmationCard(_ action: AIChatReducer.State.ExecutedAction) -> some View {
        HStack(alignment: .top, spacing: AxisSpacing.sm + 2) {
            Image(systemName: action.icon)
                .font(.title3)
                .foregroundStyle(Color.axisGreenTone)
                .frame(width: 36, height: 36)
                .background(Color.axisGreenSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.axisGreenTone)
                    Text("\(action.type.capitalized) Created")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.axisGreenTone)
                }
                Text(action.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.axisInk)
                if !action.details.isEmpty {
                    Text(action.details)
                        .font(.caption)
                        .foregroundStyle(Color.axisInkMute)
                }
            }
            Spacer()
        }
        .padding(AxisSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AxisRadius.button, style: .continuous)
                .fill(Color.axisGreenSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AxisRadius.button, style: .continuous)
                .strokeBorder(Color.axisGreenTone.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.leading, 36)
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
        HStack(alignment: .bottom, spacing: AxisSpacing.sm) {
            AssistantAvatarView()

            VStack(alignment: .leading, spacing: AxisSpacing.xs) {
                modelBadge(MultiProviderChatService.shared.selectedModel.displayName)

                Group {
                    if store.streamingContent.isEmpty {
                        HStack(spacing: AxisSpacing.sm) {
                            TypingDotsView()
                            Text("Thinking… \(Int(streamingElapsed))s")
                                .font(.caption)
                                .foregroundStyle(Color.axisInkMute)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: AxisSpacing.xs) {
                            Text(store.streamingContent)
                                .font(.axisBodyDynamic)
                                .foregroundStyle(Color.axisInk)

                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.55)
                                    .tint(Color.axisGold)
                                Text("\(Int(streamingElapsed))s")
                                    .font(.caption2)
                                    .foregroundStyle(Color.axisInkFaint)
                            }
                        }
                    }
                }
                .padding(.horizontal, AxisSpacing.lg)
                .padding(.vertical, AxisSpacing.md)
                .background {
                    ChatBubbleShape(isUser: false)
                        .fill(Color.axisPaper.opacity(0.95))
                        .overlay(
                            ChatBubbleShape(isUser: false)
                                .stroke(Color.axisHairline, lineWidth: 0.5)
                        )
                        .shadow(color: AxisTheme.cardShadow, radius: 6, y: 2)
                }
                .modifier(StreamingShimmer(isActive: store.streamingContent.isEmpty))
            }
            .frame(maxWidth: 320, alignment: .leading)

            Spacer(minLength: 24)
        }
    }

    // MARK: - Error Bubble

    private func errorBubble(_ error: String) -> some View {
        HStack(spacing: AxisSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.axisRedTone)
            Text(error)
                .font(.caption)
                .foregroundStyle(Color.axisRedTone)
            Spacer()
            Button("Dismiss") {
                store.send(.dismissError)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(Color.axisRedTone)
        }
        .padding(AxisSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AxisRadius.button, style: .continuous)
                .fill(Color.axisRedSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AxisRadius.button, style: .continuous)
                .strokeBorder(Color.axisRedTone.opacity(0.2), lineWidth: 0.5)
        )
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
            HStack(alignment: .bottom, spacing: AxisSpacing.sm) {
                Button {
                    store.send(.toggleAttachmentMenu)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.axisGold)
                }
                .buttonStyle(.plain)

                TextField("Ask AXIS anything...", text: $store.inputText.sending(\.inputTextChanged), axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(1...6)
                    .padding(.horizontal, AxisSpacing.md)
                    .padding(.vertical, AxisSpacing.sm + 2)
                    .background(
                        RoundedRectangle(cornerRadius: AxisRadius.sheet, style: .continuous)
                            .fill(Color.axisSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AxisRadius.sheet, style: .continuous)
                            .strokeBorder(
                                isInputFocused ? Color.axisGold.opacity(0.45) : Color.axisHairline,
                                lineWidth: isInputFocused ? 1.5 : 0.5
                            )
                    )
                    .animation(.easeOut(duration: 0.15), value: isInputFocused)
                    .submitLabel(.done)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button {
                                isInputFocused = false
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "keyboard.chevron.compact.down")
                                    Text("Dismiss")
                                }
                                .font(.subheadline.weight(.medium))
                            }
                        }
                    }

                Button {
                    if speechService.isRecording {
                        speechService.stopRecording()
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
                        .foregroundStyle(speechService.isRecording ? Color.axisRedTone : Color.axisInkMute)
                        .symbolEffect(.pulse, isActive: speechService.isRecording)
                }
                .buttonStyle(.plain)

                Button {
                    store.send(.sendMessage)
                } label: {
                    Image(systemName: store.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            canSend || store.isStreaming
                                ? Color.axisGold
                                : Color.axisInkFaint
                        )
                        .shadow(color: (canSend || store.isStreaming) ? Color.axisGold.opacity(0.3) : .clear, radius: 6, y: 2)
                }
                .disabled(!canSend && !store.isStreaming)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AxisSpacing.md)
            .padding(.vertical, AxisSpacing.sm + 2)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider()
                }
                .shadow(color: AxisTheme.cardShadow, radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
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

// MARK: - Chat Bubble Shape

private struct ChatBubbleShape: InsettableShape {
    let isUser: Bool
    var inset: CGFloat = 0
    private let radius: CGFloat = AxisRadius.card
    private let tailRadius: CGFloat = 4

    func inset(by amount: CGFloat) -> ChatBubbleShape {
        ChatBubbleShape(isUser: isUser, inset: inset + amount)
    }

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        let corners: RectangleCornerRadii
        if isUser {
            corners = RectangleCornerRadii(
                topLeading: radius,
                bottomLeading: radius,
                bottomTrailing: tailRadius,
                topTrailing: radius
            )
        } else {
            corners = RectangleCornerRadii(
                topLeading: radius,
                bottomLeading: tailRadius,
                bottomTrailing: radius,
                topTrailing: radius
            )
        }
        return UnevenRoundedRectangle(cornerRadii: corners, style: .continuous)
            .path(in: rect)
    }
}

// MARK: - Assistant Avatar

private struct AssistantAvatarView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.axisGold.opacity(0.25), Color.axisGold.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.axisGold)
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Streaming Shimmer

private struct StreamingShimmer: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.shimmer()
        } else {
            content
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
