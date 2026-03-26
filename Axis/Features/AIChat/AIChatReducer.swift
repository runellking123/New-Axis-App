import ComposableArchitecture
import Foundation
import UIKit

@Reducer
struct AIChatReducer {
    @ObservableState
    struct State: Equatable {
        var messages: [MessageState] = []
        var threads: [ThreadState] = []
        var selectedThreadId: UUID?
        var inputText: String = ""
        var isStreaming: Bool = false
        var streamingContent: String = ""
        var error: String?
        var isConfigured: Bool = false
        var selectedModelName: String = ""
        var showThreadList: Bool = false
        var showModelPicker: Bool = false

        // Attachment state
        var attachedImages: [Data] = []         // JPEG data for attached photos
        var attachedFileNames: [String] = []    // Names of attached files
        var attachedFileData: [Data] = []       // Raw file data
        var showAttachmentMenu: Bool = false
        var showImagePicker: Bool = false
        var showFilePicker: Bool = false
        var showCamera: Bool = false
        var isRecordingVoice: Bool = false
        var voiceTranscript: String = ""
        var suggestedFollowUps: [String] = []

        struct MessageState: Equatable, Identifiable {
            let id: UUID
            var role: String
            var content: String
            var model: String
            var timestamp: Date
            var hasAttachments: Bool = false
            var attachmentCount: Int = 0
        }

        struct ThreadState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var updatedAt: Date
        }
    }

    enum Action: Equatable {
        case onAppear
        case inputTextChanged(String)
        case sendMessage
        case streamChunkReceived(String)
        case streamCompleted
        case streamError(String)
        case messagesLoaded([State.MessageState])
        case threadsLoaded([State.ThreadState])
        case selectThread(UUID?)
        case createNewThread
        case deleteThread(UUID)
        case toggleThreadList
        case dismissThreadList
        case toggleModelPicker
        case dismissModelPicker
        case modelSelected(String)
        case dismissError
        case quickAction(String)

        // Follow-up actions
        case followUpsGenerated([String])
        case tappedFollowUp(String)

        // Attachment actions
        case toggleAttachmentMenu
        case dismissAttachmentMenu
        case toggleImagePicker
        case dismissImagePicker
        case toggleFilePicker
        case dismissFilePicker
        case toggleCamera
        case addImage(Data)
        case addFile(String, Data)          // filename, data
        case removeAttachment(Int)
        case clearAttachments

        // Thread actions
        case clearAllThreads

        // Message actions
        case copyMessage(String)
        case regenerateLastResponse
        case editAndResend(UUID, String)    // messageId, newContent
    }

    @Dependency(\.axisPersistence) var persistence
    @Dependency(\.axisHaptics) var haptics

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let service = MultiProviderChatService.shared
                state.isConfigured = service.isConfigured
                state.selectedModelName = service.selectedModel.displayName
                return .run { send in
                    let threads = persistence.fetchChatThreads()
                    let threadStates = threads.map { t in
                        State.ThreadState(id: t.uuid, title: t.title, updatedAt: t.updatedAt)
                    }.sorted { $0.updatedAt > $1.updatedAt }
                    await send(.threadsLoaded(threadStates))

                    if let first = threads.first {
                        let messages = persistence.fetchChatMessages(first.uuid)
                        let msgStates = messages.map { m in
                            State.MessageState(id: m.uuid, role: m.role, content: m.content, model: m.model, timestamp: m.timestamp)
                        }.sorted { $0.timestamp < $1.timestamp }
                        await send(.selectThread(first.uuid))
                        await send(.messagesLoaded(msgStates))
                    }
                }

            case let .inputTextChanged(text):
                state.inputText = text
                return .none

            case .sendMessage:
                let text = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, !state.isStreaming else { return .none }

                // Create thread if needed
                var threadId = state.selectedThreadId
                if threadId == nil {
                    let service = MultiProviderChatService.shared
                    let thread = ChatThread(title: String(text.prefix(40)), modelUsed: service.selectedModelId)
                    persistence.saveChatThread(thread)
                    threadId = thread.uuid
                    state.selectedThreadId = threadId
                    state.threads.insert(State.ThreadState(id: thread.uuid, title: thread.title, updatedAt: thread.updatedAt), at: 0)
                }

                // Determine attachment info
                let imageCount = state.attachedImages.count
                let fileCount = state.attachedFileNames.count
                let totalAttachments = imageCount + fileCount
                let hasAttachments = totalAttachments > 0

                // Build display content with attachment info
                var displayContent = text
                if hasAttachments {
                    var parts: [String] = []
                    if imageCount > 0 { parts.append("\(imageCount) image\(imageCount > 1 ? "s" : "")") }
                    if fileCount > 0 { parts.append("\(fileCount) file\(fileCount > 1 ? "s" : "")") }
                    displayContent += "\n[\(parts.joined(separator: ", ")) attached]"
                }

                // Add user message
                let userMsg = State.MessageState(
                    id: UUID(), role: "user", content: displayContent, model: "",
                    timestamp: Date(), hasAttachments: hasAttachments, attachmentCount: totalAttachments
                )
                state.messages.append(userMsg)
                state.inputText = ""
                state.isStreaming = true
                state.streamingContent = ""
                state.error = nil
                state.suggestedFollowUps = []

                // Save user message
                let chatMsg = ChatMessage(role: "user", content: displayContent, threadId: threadId)
                persistence.saveChatMessage(chatMsg)

                haptics.selection()

                // Build history with image support
                var history: [(role: String, content: String)] = []
                for msg in state.messages {
                    history.append((role: msg.role, content: msg.content))
                }

                // Capture attached images for future multi-modal API support (base64-encoded for Anthropic)
                _ = state.attachedImages

                // Clear attachments after capturing
                state.attachedImages = []
                state.attachedFileNames = []
                state.attachedFileData = []
                state.showAttachmentMenu = false

                return .run { send in
                    let service = MultiProviderChatService.shared
                    let stream = service.streamChat(messages: history)
                    do {
                        for try await chunk in stream {
                            if let text = chunk.text {
                                await send(.streamChunkReceived(text))
                            }
                            if let error = chunk.error {
                                await send(.streamError(error))
                                return
                            }
                            if chunk.isComplete {
                                await send(.streamCompleted)
                                return
                            }
                        }
                        await send(.streamCompleted)
                    } catch {
                        await send(.streamError(error.localizedDescription))
                    }
                }

            case let .streamChunkReceived(text):
                state.streamingContent += text
                return .none

            case .streamCompleted:
                let content = state.streamingContent
                let service = MultiProviderChatService.shared
                let assistantMsg = State.MessageState(
                    id: UUID(), role: "assistant", content: content,
                    model: service.selectedModel.displayName, timestamp: Date()
                )
                state.messages.append(assistantMsg)
                state.isStreaming = false
                state.streamingContent = ""

                // Save assistant message
                let chatMsg = ChatMessage(role: "assistant", content: content, model: service.selectedModelId, threadId: state.selectedThreadId)
                persistence.saveChatMessage(chatMsg)

                // Update thread timestamp
                if let threadId = state.selectedThreadId {
                    persistence.updateChatThreadTimestamp(threadId)
                }

                haptics.notificationSuccess()

                // Generate follow-up suggestions
                let lastContent = content
                return .run { send in
                    let service = MultiProviderChatService.shared
                    let key = service.anthropicAPIKey
                    guard !key.isEmpty else { return }
                    let url = URL(string: "https://api.anthropic.com/v1/messages")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(key, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.timeoutInterval = 10
                    let body: [String: Any] = [
                        "model": "claude-sonnet-4-20250514",
                        "max_tokens": 80,
                        "messages": [["role": "user", "content": "Based on this response, suggest 3 short follow-up questions (max 6 words each). Return ONLY a JSON array of 3 strings. Response: \(String(lastContent.prefix(300)))"]]
                    ]
                    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                    do {
                        let (data, _) = try await URLSession.shared.data(for: request)
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let content = json["content"] as? [[String: Any]],
                           let text = content.first?["text"] as? String,
                           let jsonData = text.data(using: .utf8),
                           let suggestions = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
                            await send(.followUpsGenerated(Array(suggestions.prefix(3))))
                        }
                    } catch {}
                }

            case let .streamError(error):
                state.error = error
                state.isStreaming = false
                state.streamingContent = ""
                return .none

            case let .messagesLoaded(messages):
                state.messages = messages
                return .none

            case let .threadsLoaded(threads):
                state.threads = threads
                return .none

            case let .selectThread(id):
                state.selectedThreadId = id
                state.showThreadList = false
                guard let id else {
                    state.messages = []
                    return .none
                }
                return .run { send in
                    let messages = persistence.fetchChatMessages(id)
                    let msgStates = messages.map { m in
                        State.MessageState(id: m.uuid, role: m.role, content: m.content, model: m.model, timestamp: m.timestamp)
                    }.sorted { $0.timestamp < $1.timestamp }
                    await send(.messagesLoaded(msgStates))
                }

            case .createNewThread:
                state.selectedThreadId = nil
                state.messages = []
                state.inputText = ""
                state.showThreadList = false
                return .none

            case let .deleteThread(id):
                state.threads.removeAll { $0.id == id }
                persistence.deleteChatThread(id)
                if state.selectedThreadId == id {
                    state.selectedThreadId = nil
                    state.messages = []
                }
                return .none

            case .clearAllThreads:
                for thread in state.threads {
                    persistence.deleteChatThread(thread.id)
                }
                state.threads = []
                state.messages = []
                state.selectedThreadId = nil
                state.showThreadList = false
                haptics.notificationSuccess()
                return .none

            case .toggleThreadList:
                state.showThreadList.toggle()
                return .none

            case .dismissThreadList:
                state.showThreadList = false
                return .none

            case .toggleModelPicker:
                state.showModelPicker.toggle()
                return .none

            case .dismissModelPicker:
                state.showModelPicker = false
                return .none

            case let .modelSelected(modelId):
                MultiProviderChatService.shared.selectedModelId = modelId
                state.selectedModelName = MultiProviderChatService.shared.selectedModel.displayName
                state.isConfigured = MultiProviderChatService.shared.isConfigured
                state.showModelPicker = false
                return .none

            case .dismissError:
                state.error = nil
                return .none

            case let .quickAction(prompt):
                state.inputText = prompt
                return .send(.sendMessage)

            // MARK: - Follow-Up Actions

            case let .followUpsGenerated(suggestions):
                state.suggestedFollowUps = suggestions
                return .none

            case let .tappedFollowUp(prompt):
                state.suggestedFollowUps = []
                state.inputText = prompt
                return .send(.sendMessage)

            // MARK: - Attachment Actions

            case .toggleAttachmentMenu:
                state.showAttachmentMenu.toggle()
                return .none

            case .dismissAttachmentMenu:
                state.showAttachmentMenu = false
                return .none

            case .toggleImagePicker:
                state.showImagePicker.toggle()
                state.showAttachmentMenu = false
                return .none

            case .dismissImagePicker:
                state.showImagePicker = false
                return .none

            case .toggleFilePicker:
                state.showFilePicker.toggle()
                state.showAttachmentMenu = false
                return .none

            case .dismissFilePicker:
                state.showFilePicker = false
                return .none

            case .toggleCamera:
                state.showCamera.toggle()
                state.showAttachmentMenu = false
                return .none

            case let .addImage(data):
                state.attachedImages.append(data)
                state.showImagePicker = false
                state.showCamera = false
                return .none

            case let .addFile(filename, data):
                state.attachedFileNames.append(filename)
                state.attachedFileData.append(data)
                state.showFilePicker = false
                return .none

            case let .removeAttachment(index):
                // Determine which array the index falls into
                // Images come first, then files
                let imageCount = state.attachedImages.count
                if index < imageCount {
                    state.attachedImages.remove(at: index)
                } else {
                    let fileIndex = index - imageCount
                    if fileIndex < state.attachedFileNames.count {
                        state.attachedFileNames.remove(at: fileIndex)
                        state.attachedFileData.remove(at: fileIndex)
                    }
                }
                return .none

            case .clearAttachments:
                state.attachedImages = []
                state.attachedFileNames = []
                state.attachedFileData = []
                return .none

            // MARK: - Message Actions

            case let .copyMessage(content):
                UIPasteboard.general.string = content
                haptics.selection()
                return .none

            case .regenerateLastResponse:
                guard !state.isStreaming else { return .none }

                // Find the last assistant message
                guard let lastAssistantIndex = state.messages.lastIndex(where: { $0.role == "assistant" }) else {
                    return .none
                }

                let lastAssistantMsg = state.messages[lastAssistantIndex]

                // Remove it from state
                state.messages.remove(at: lastAssistantIndex)

                // Remove from persistence
                persistence.deleteChatMessage(lastAssistantMsg.id)

                // Ensure there's a user message to re-send
                guard state.messages.contains(where: { $0.role == "user" }) else {
                    return .none
                }

                // Set up streaming
                state.isStreaming = true
                state.streamingContent = ""
                state.error = nil

                // Build history from remaining messages
                let history = state.messages.map { (role: $0.role, content: $0.content) }

                haptics.selection()

                return .run { send in
                    let service = MultiProviderChatService.shared
                    let stream = service.streamChat(messages: history)
                    do {
                        for try await chunk in stream {
                            if let text = chunk.text {
                                await send(.streamChunkReceived(text))
                            }
                            if let error = chunk.error {
                                await send(.streamError(error))
                                return
                            }
                            if chunk.isComplete {
                                await send(.streamCompleted)
                                return
                            }
                        }
                        await send(.streamCompleted)
                    } catch {
                        await send(.streamError(error.localizedDescription))
                    }
                }

            case let .editAndResend(messageId, newContent):
                guard !state.isStreaming else { return .none }

                // Find the message index
                guard let messageIndex = state.messages.firstIndex(where: { $0.id == messageId }) else {
                    return .none
                }

                // Collect IDs of messages to remove (the target and all subsequent)
                let messagesToRemove = Array(state.messages[messageIndex...])
                let idsToRemove = messagesToRemove.map(\.id)

                // Remove from state
                state.messages.removeSubrange(messageIndex...)

                // Remove from persistence
                for id in idsToRemove {
                    persistence.deleteChatMessage(id)
                }

                // Set the input text to the new content and send
                state.inputText = newContent
                return .send(.sendMessage)
            }
        }
    }
}
