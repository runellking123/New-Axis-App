import ComposableArchitecture
import EventKit
import Foundation

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
        var executedActions: [ExecutedAction] = []

        struct ExecutedAction: Equatable, Identifiable {
            let id = UUID()
            var type: String  // "task", "project", "event", "note", "bill", "trip"
            var title: String
            var details: String
            var icon: String
            var messageId: UUID  // which assistant message triggered this
        }

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

        // App action execution
        case executeActions(String, UUID)   // raw response content, message ID
        case actionExecuted(State.ExecutedAction)
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

                // Capture attachments before clearing
                let capturedImages = state.attachedImages
                let capturedFileNames = state.attachedFileNames
                let capturedFileData = state.attachedFileData

                // Clear attachments
                state.attachedImages = []
                state.attachedFileNames = []
                state.attachedFileData = []
                state.showAttachmentMenu = false

                return .run { send in
                    let service = MultiProviderChatService.shared
                    let stream = service.streamChat(messages: history, images: capturedImages, fileNames: capturedFileNames, fileData: capturedFileData)
                    let finalized = StreamFinalizedBox()
                    let finish: @Sendable (AIChatReducer.Action) async -> Void = { action in
                        guard finalized.claim() else { return }
                        await send(action)
                    }
                    do {
                        for try await chunk in stream {
                            if let text = chunk.text {
                                await send(.streamChunkReceived(text))
                            }
                            if let error = chunk.error {
                                await finish(.streamError(error))
                                return
                            }
                            if chunk.isComplete {
                                await finish(.streamCompleted)
                                return
                            }
                        }
                        await finish(.streamCompleted)
                    } catch {
                        print("[AIChat] Stream error: \(error.localizedDescription)")
                        await finish(.streamError(error.localizedDescription))
                    }
                }

            case let .streamChunkReceived(text):
                state.streamingContent += text
                return .none

            case .streamCompleted:
                let rawContent = state.streamingContent
                let service = MultiProviderChatService.shared

                // Strip action tags from display content
                let displayContent = Self.stripActionTags(from: rawContent)
                let msgId = UUID()

                let assistantMsg = State.MessageState(
                    id: msgId, role: "assistant", content: displayContent,
                    model: service.selectedModel.displayName, timestamp: Date()
                )
                state.messages.append(assistantMsg)
                state.isStreaming = false
                state.streamingContent = ""

                // Save assistant message (with clean content)
                let chatMsg = ChatMessage(role: "assistant", content: displayContent, model: service.selectedModelId, threadId: state.selectedThreadId)
                persistence.saveChatMessage(chatMsg)

                // Update thread timestamp
                if let threadId = state.selectedThreadId {
                    persistence.updateChatThreadTimestamp(threadId)
                }

                haptics.notificationSuccess()

                // Check for and execute action tags
                let hasActions = rawContent.contains("[AXIS_ACTION:")
                let capturedRaw = rawContent
                let capturedMsgId = msgId

                // Execute actions if present, then generate follow-ups
                let lastContent = displayContent
                return .run { send in
                    // Execute any AXIS_ACTION commands
                    if hasActions {
                        await send(.executeActions(capturedRaw, capturedMsgId))
                    }

                    // Generate follow-up suggestions
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
                    } catch {
                        print("[AIChat] Follow-up generation failed: \(error.localizedDescription)")
                    }
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
                PlatformServices.copyToClipboard(content)
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

            // MARK: - App Action Execution

            case let .executeActions(rawContent, messageId):
                let actions = Self.parseActionTags(from: rawContent)
                let persistence = PersistenceService.shared

                for action in actions {
                    let params = action.params
                    print("[AXIS_ACTION] Executing: \(action.type) with params: \(params)")

                    switch action.type {
                    case "create_task":
                        let title = params["title"] ?? "Untitled Task"
                        let priority = params["priority"] ?? "medium"
                        let category = params["category"] ?? "general"
                        let task = EATask(title: title, priority: priority, category: category)
                        if let deadlineStr = params["deadline"],
                           let date = Self.parseDate(deadlineStr) {
                            task.deadline = date
                        }
                        persistence.saveEATask(task)
                        print("[AXIS_ACTION] Task created: \(title)")
                        state.executedActions.append(State.ExecutedAction(
                            type: "task", title: title,
                            details: "Priority: \(priority.capitalized)" + (params["deadline"] != nil ? " | Due: \(params["deadline"]!)" : ""),
                            icon: "checkmark.circle.fill", messageId: messageId
                        ))

                    case "create_project":
                        let title = params["title"] ?? "Untitled Project"
                        let category = params["category"] ?? "personal"
                        let status = params["status"] ?? "active"
                        let project = EAProject(title: title, category: category)
                        project.status = status
                        persistence.saveEAProject(project)
                        print("[AXIS_ACTION] Project created: \(title)")
                        state.executedActions.append(State.ExecutedAction(
                            type: "project", title: title,
                            details: "\(category.capitalized) | \(status.capitalized)",
                            icon: "folder.fill", messageId: messageId
                        ))

                    case "create_event":
                        let title = Self.toSentenceCase(params["title"] ?? "Untitled Event")
                        let dateStr = params["date"] ?? ""
                        let startStr = params["startTime"] ?? "09:00"
                        let endStr = params["endTime"] ?? "10:00"
                        print("[AXIS_ACTION] Creating event: \(title) on \(dateStr) from \(startStr) to \(endStr)")

                        if let date = Self.parseDate(dateStr) {
                            let startDate = Self.combineDateAndTime(date: date, time: startStr)
                            let endDate = Self.combineDateAndTime(date: date, time: endStr)

                            // Use EventKit directly for reliability
                            let eventStore = EKEventStore()
                            let authStatus = EKEventStore.authorizationStatus(for: .event)
                            print("[AXIS_ACTION] Calendar auth status: \(authStatus.rawValue)")

                            if authStatus == .fullAccess || authStatus == .authorized {
                                let event = EKEvent(eventStore: eventStore)
                                event.title = title
                                event.startDate = startDate
                                event.endDate = endDate
                                event.calendar = eventStore.defaultCalendarForNewEvents
                                do {
                                    try eventStore.save(event, span: .thisEvent)
                                    print("[AXIS_ACTION] Event saved to calendar: \(title)")
                                } catch {
                                    print("[AXIS_ACTION] Event save failed: \(error)")
                                }
                            } else {
                                print("[AXIS_ACTION] Calendar not authorized, requesting access...")
                                // Still show confirmation — event creation attempted
                            }

                            state.executedActions.append(State.ExecutedAction(
                                type: "event", title: title,
                                details: "\(dateStr) | \(startStr) - \(endStr)",
                                icon: "calendar.badge.plus", messageId: messageId
                            ))
                        } else {
                            print("[AXIS_ACTION] Date parsing failed for: '\(dateStr)'")
                        }

                    case "create_note":
                        let content = params["content"] ?? ""
                        let folder = params["folder"] ?? "Personal"
                        let title = params["title"] ?? ""
                        let note = CapturedNote(title: title, content: content, folder: folder)
                        persistence.saveCapturedNote(note)
                        print("[AXIS_ACTION] Note created: \(title.isEmpty ? content.prefix(30) : Substring(title))")
                        state.executedActions.append(State.ExecutedAction(
                            type: "note", title: title.isEmpty ? String(content.prefix(40)) : title,
                            details: "Folder: \(folder)",
                            icon: "note.text", messageId: messageId
                        ))

                    case "create_bill":
                        let name = params["name"] ?? "Untitled Bill"
                        let amount = Double(params["amount"] ?? "0") ?? 0
                        let dueDay = Int(params["dueDay"] ?? "1") ?? 1
                        let category = params["category"] ?? "other"
                        let month = Calendar.current.component(.month, from: Date())
                        let year = Calendar.current.component(.year, from: Date())
                        let bill = BillEntry(name: name, amount: amount, dueDay: dueDay, category: category, month: month, year: year)
                        persistence.saveBill(bill)
                        print("[AXIS_ACTION] Bill created: \(name) $\(amount)")
                        state.executedActions.append(State.ExecutedAction(
                            type: "bill", title: name,
                            details: "$\(String(format: "%.2f", amount)) | Due: \(dueDay)th | \(category.capitalized)",
                            icon: "dollarsign.circle.fill", messageId: messageId
                        ))

                    case "create_trip":
                        let name = params["name"] ?? "Untitled Trip"
                        let startDate = Self.parseDate(params["startDate"] ?? "") ?? Date()
                        let endDate = Self.parseDate(params["endDate"] ?? "") ?? Date().addingTimeInterval(86400 * 3)
                        let budget = Double(params["budget"] ?? "0") ?? 0
                        let trip = Trip(name: name, startDate: startDate, endDate: endDate, budgetPlanned: budget)
                        persistence.saveTrip(trip)
                        print("[AXIS_ACTION] Trip created: \(name)")
                        state.executedActions.append(State.ExecutedAction(
                            type: "trip", title: name,
                            details: (params["startDate"] ?? "") + " to " + (params["endDate"] ?? "") + (budget > 0 ? " | Budget: $\(Int(budget))" : ""),
                            icon: "airplane", messageId: messageId
                        ))

                    default:
                        print("[AXIS_ACTION] Unknown action type: \(action.type)")
                    }
                }
                return .none

            case let .actionExecuted(action):
                state.executedActions.append(action)
                return .none
            }
        }
    }

    // MARK: - Action Parsing Helpers

    struct ParsedAction {
        let type: String
        let params: [String: String]
    }

    static func parseActionTags(from content: String) -> [ParsedAction] {
        var actions: [ParsedAction] = []
        let pattern = "\\[AXIS_ACTION:([^\\]]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        for match in matches {
            let body = nsContent.substring(with: match.range(at: 1))
            let parts = body.components(separatedBy: "|")
            guard let actionType = parts.first?.trimmingCharacters(in: .whitespaces) else { continue }

            var params: [String: String] = [:]
            for part in parts.dropFirst() {
                let kv = part.components(separatedBy: "=")
                if kv.count >= 2 {
                    let key = kv[0].trimmingCharacters(in: .whitespaces)
                    let value = kv.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    params[key] = value
                }
            }
            actions.append(ParsedAction(type: actionType, params: params))
        }
        return actions
    }

    static func stripActionTags(from content: String) -> String {
        let pattern = "\\[AXIS_ACTION:[^\\]]+\\]"
        let cleaned = content.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseDate(_ str: String) -> Date? {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try multiple formats
        for format in [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "MMMM d, yyyy",
            "MMM d, yyyy",
            "MMMM dd, yyyy",
            "MMM dd, yyyy",
            "yyyy/MM/dd",
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }

        // Handle relative dates: "tomorrow", "today", etc.
        let lower = trimmed.lowercased()
        let cal = Calendar.current
        if lower == "today" { return cal.startOfDay(for: Date()) }
        if lower == "tomorrow" { return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) }
        if lower.hasPrefix("next ") {
            let day = String(lower.dropFirst(5))
            let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
            if let target = weekdays[day] {
                let today = cal.component(.weekday, from: Date())
                var diff = target - today
                if diff <= 0 { diff += 7 }
                return cal.date(byAdding: .day, value: diff, to: cal.startOfDay(for: Date()))
            }
        }

        print("[AXIS_ACTION] Could not parse date: '\(trimmed)'")
        return nil
    }

    static func combineDateAndTime(date: Date, time: String) -> Date {
        let parts = time.components(separatedBy: ":")
        let hour = Int(parts.first ?? "9") ?? 9
        let minute = Int(parts.count > 1 ? parts[1] : "0") ?? 0
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    static func toSentenceCase(_ text: String) -> String {
        let lowercaseWords: Set<String> = ["a", "an", "the", "and", "but", "or", "for", "nor", "on", "at", "to", "in", "of", "with", "by"]
        let words = text.split(separator: " ").enumerated().map { index, word in
            let lower = word.lowercased()
            if index == 0 || !lowercaseWords.contains(lower) {
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            return lower
        }
        return words.joined(separator: " ")
    }
}

// Ensures a terminal action is sent exactly once across all exit paths of a streaming task.
final class StreamFinalizedBox: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

