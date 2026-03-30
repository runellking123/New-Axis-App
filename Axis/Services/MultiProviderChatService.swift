import Foundation

enum AIModelProvider: String, CaseIterable, Identifiable {
    case claude = "Claude"
    case gemini = "Gemini"
    var id: String { rawValue }
}

struct AIModel: Identifiable, Equatable {
    let id: String
    let displayName: String
    let provider: AIModelProvider

    static let allModels: [AIModel] = [
        AIModel(id: "claude-sonnet-4-20250514", displayName: "Claude Sonnet 4", provider: .claude),
        AIModel(id: "claude-haiku-4-5-20251001", displayName: "Claude Haiku 4.5", provider: .claude),
        AIModel(id: "claude-opus-4-20250514", displayName: "Claude Opus 4", provider: .claude),
        AIModel(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro", provider: .gemini),
        AIModel(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash", provider: .gemini),
    ]
}

struct ChatStreamChunk {
    let text: String?
    let isComplete: Bool
    let error: String?
}

@Observable
final class MultiProviderChatService: @unchecked Sendable {
    static let shared = MultiProviderChatService()

    private(set) var isStreaming = false
    private static let defaultAnthropicKey: String = Secrets.anthropicAPIKey
    private static let defaultGeminiKey: String = Secrets.geminiAPIKey

    var anthropicAPIKey: String {
        get { Self.defaultAnthropicKey }
        set { /* embedded */ }
    }
    var geminiAPIKey: String {
        get { Self.defaultGeminiKey }
        set { /* embedded */ }
    }
    var selectedModelId: String {
        get { UserDefaults.standard.string(forKey: "selected_ai_model") ?? "claude-sonnet-4-20250514" }
        set { UserDefaults.standard.set(newValue, forKey: "selected_ai_model") }
    }

    var selectedModel: AIModel {
        AIModel.allModels.first { $0.id == selectedModelId } ?? AIModel.allModels[0]
    }

    var isConfigured: Bool {
        let model = selectedModel
        switch model.provider {
        case .claude: return !anthropicAPIKey.isEmpty
        case .gemini: return !geminiAPIKey.isEmpty
        }
    }

    private let systemPrompt = """
    You are AXIS, a versatile AI assistant for Dr. Runell King. You can help with ANY topic — \
    general knowledge, coding, writing, brainstorming, personal questions, advice, analysis, \
    creative work, math, science, history, current events, or anything else. You are a \
    full-featured AI assistant, not limited to any single domain.

    USER CONTEXT (use when relevant, ignore otherwise):
    Dr. King is Vice President for Institutional Research, Effectiveness & Strategic Retention \
    at Wiley University (HBCU). He also runs IR Analytics Consulting and builds iOS apps \
    (WileyAnalytics, HTAnalytics, AXIS).

    RESPONSE FORMAT:
    - Use plain text only. No asterisks, markdown, bold, or special formatting
    - Use dashes for lists, not bullets or asterisks
    - Be concise but thorough — match response length to the complexity of the question
    - For simple questions, keep it brief. For complex topics, give a complete answer
    - Follow direct instructions immediately without asking unnecessary clarifying questions
    - Get straight to the answer

    APP ACTIONS:
    You can execute actions inside the AXIS app. When the user asks you to create, add, or schedule something, include the appropriate action tag in your response. Confirm what you did in natural language BEFORE the action tag.

    Available actions (use EXACTLY this format, one per line, at the END of your response):

    [AXIS_ACTION:create_task|title=TITLE|priority=high|category=university|deadline=YYYY-MM-DD]
    - priority: critical, high, medium, low (default: medium)
    - category: university, consulting, personal, general (default: general)
    - deadline: optional, use YYYY-MM-DD format

    [AXIS_ACTION:create_project|title=TITLE|category=university|status=active]
    - category: university, consulting, personal (default: personal)
    - status: active, onHold (default: active)

    [AXIS_ACTION:create_event|title=TITLE|date=YYYY-MM-DD|startTime=HH:MM|endTime=HH:MM]
    - date is required. startTime and endTime are optional — default to 09:00 and 10:00 if not specified
    - If the user does not mention a time, do NOT ask — just use the defaults (work day hours)
    - Use 24-hour format for times
    - Always use Sentence Case for the event title (capitalize first letter of each major word)

    [AXIS_ACTION:create_note|content=CONTENT|folder=Work|title=TITLE]
    - folder: Work, Personal, Lagniappe (default: Personal)
    - title: optional

    [AXIS_ACTION:create_bill|name=NAME|amount=AMOUNT|dueDay=DAY|category=CATEGORY]
    - amount: number (e.g. 150.00)
    - dueDay: 1-31
    - category: housing, utilities, transportation, insurance, subscriptions, debt, food, childcare, phone, other

    [AXIS_ACTION:create_trip|name=NAME|startDate=YYYY-MM-DD|endDate=YYYY-MM-DD|budget=AMOUNT]
    - budget: optional number

    IMPORTANT: Only include action tags when the user explicitly asks you to create, add, schedule, or save something. Do not include action tags for questions, analysis, or general conversation.
    """

    // MARK: - Streaming Chat

    func streamChat(
        messages: [(role: String, content: String)],
        model: AIModel? = nil,
        images: [Data] = [],
        fileNames: [String] = [],
        fileData: [Data] = []
    ) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        let activeModel = model ?? selectedModel
        switch activeModel.provider {
        case .claude:
            return streamClaude(messages: messages, model: activeModel.id, images: images, fileNames: fileNames, fileData: fileData)
        case .gemini:
            return streamGemini(messages: messages, model: activeModel.id)
        }
    }

    // MARK: - Claude (Anthropic Messages API)

    private func streamClaude(
        messages: [(role: String, content: String)],
        model: String,
        images: [Data] = [],
        fileNames: [String] = [],
        fileData: [Data] = []
    ) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(string: "https://api.anthropic.com/v1/messages")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(anthropicAPIKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    // Build dynamic system prompt with current user data
                    var dynamicSystem = self.systemPrompt
                    let persistence = PersistenceService.shared
                    let allTasks = persistence.fetchEATasks()
                    let taskCount = allTasks.count
                    let completedCount = allTasks.filter { $0.status == "completed" }.count
                    let projectCount = persistence.fetchEAProjects().count
                    dynamicSystem += "\n\nCURRENT USER DATA:\n- Total tasks: \(taskCount) (\(completedCount) completed)\n- Active projects: \(projectCount)\n- Current date: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))"

                    // Build messages array — last user message gets multimodal content if attachments exist
                    var msgArray: [[String: Any]] = []
                    let hasAttachments = !images.isEmpty || !fileData.isEmpty

                    for (i, msg) in messages.enumerated() {
                        let isLastUserMsg = (i == messages.count - 1) && msg.role == "user" && hasAttachments

                        if isLastUserMsg {
                            // Build multimodal content array for the last user message
                            var contentParts: [[String: Any]] = []

                            // Add images as base64
                            for imageData in images {
                                let base64 = imageData.base64EncodedString()
                                contentParts.append([
                                    "type": "image",
                                    "source": [
                                        "type": "base64",
                                        "media_type": "image/jpeg",
                                        "data": base64
                                    ]
                                ])
                            }

                            // Add file content as text (extract text from files)
                            for (idx, data) in fileData.enumerated() {
                                let fileName = idx < fileNames.count ? fileNames[idx] : "file"
                                let ext = (fileName as NSString).pathExtension.lowercased()

                                if ["png", "jpg", "jpeg", "gif", "webp"].contains(ext) {
                                    // Image file — send as image
                                    let base64 = data.base64EncodedString()
                                    let mediaType = ext == "png" ? "image/png" : ext == "gif" ? "image/gif" : ext == "webp" ? "image/webp" : "image/jpeg"
                                    contentParts.append([
                                        "type": "image",
                                        "source": [
                                            "type": "base64",
                                            "media_type": mediaType,
                                            "data": base64
                                        ]
                                    ])
                                } else if ["pdf"].contains(ext) {
                                    // PDF — send as document
                                    let base64 = data.base64EncodedString()
                                    contentParts.append([
                                        "type": "document",
                                        "source": [
                                            "type": "base64",
                                            "media_type": "application/pdf",
                                            "data": base64
                                        ]
                                    ])
                                } else {
                                    // Text-based file — extract content
                                    let textContent = String(data: data, encoding: .utf8) ?? "(Could not read file content)"
                                    contentParts.append([
                                        "type": "text",
                                        "text": "--- File: \(fileName) ---\n\(textContent)\n--- End of file ---"
                                    ])
                                }
                            }

                            // Add the user's text message
                            // Strip the "[X attached]" suffix since we're sending actual content
                            var cleanText = msg.content
                            if let range = cleanText.range(of: "\n[", options: .backwards) {
                                cleanText = String(cleanText[..<range.lowerBound])
                            }
                            contentParts.append([
                                "type": "text",
                                "text": cleanText
                            ])

                            msgArray.append(["role": "user", "content": contentParts])
                        } else {
                            msgArray.append(["role": msg.role, "content": msg.content])
                        }
                    }

                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 4096,
                        "stream": true,
                        "system": dynamicSystem,
                        "messages": msgArray
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.yield(ChatStreamChunk(text: nil, isComplete: false, error: "Invalid response"))
                        continuation.finish()
                        return
                    }
                    if http.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines { errorBody += line }
                        continuation.yield(ChatStreamChunk(text: nil, isComplete: false, error: "HTTP \(http.statusCode): \(errorBody)"))
                        continuation.finish()
                        return
                    }

                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data: ") else { continue }
                        let jsonStr = String(trimmed.dropFirst(6))
                        guard jsonStr != "[DONE]",
                              let data = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                        let eventType = json["type"] as? String ?? ""
                        if eventType == "content_block_delta",
                           let delta = json["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            continuation.yield(ChatStreamChunk(text: text, isComplete: false, error: nil))
                        } else if eventType == "message_stop" {
                            continuation.yield(ChatStreamChunk(text: nil, isComplete: true, error: nil))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(ChatStreamChunk(text: nil, isComplete: false, error: error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Gemini (Google AI API)

    private func streamGemini(
        messages: [(role: String, content: String)],
        model: String
    ) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?key=\(geminiAPIKey)&alt=sse")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    // Build dynamic system prompt with current user data
                    var dynamicSystem = self.systemPrompt
                    let persistence = PersistenceService.shared
                    let allTasks = persistence.fetchEATasks()
                    let taskCount = allTasks.count
                    let completedCount = allTasks.filter { $0.status == "completed" }.count
                    let projectCount = persistence.fetchEAProjects().count
                    dynamicSystem += "\n\nCURRENT USER DATA:\n- Total tasks: \(taskCount) (\(completedCount) completed)\n- Active projects: \(projectCount)\n- Current date: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))"

                    var contents: [[String: Any]] = []
                    // Add system instruction
                    let systemParts: [[String: Any]] = [["text": dynamicSystem]]

                    for msg in messages {
                        let role = msg.role == "assistant" ? "model" : "user"
                        contents.append(["role": role, "parts": [["text": msg.content]]])
                    }

                    let body: [String: Any] = [
                        "contents": contents,
                        "systemInstruction": ["parts": systemParts],
                        "generationConfig": [
                            "maxOutputTokens": 4096,
                            "temperature": 0.7
                        ]
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.yield(ChatStreamChunk(text: nil, isComplete: false, error: "Invalid response"))
                        continuation.finish()
                        return
                    }
                    if http.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines { errorBody += line }
                        continuation.yield(ChatStreamChunk(text: nil, isComplete: false, error: "HTTP \(http.statusCode): \(errorBody)"))
                        continuation.finish()
                        return
                    }

                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data: ") else { continue }
                        let jsonStr = String(trimmed.dropFirst(6))
                        guard let data = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                        if let candidates = json["candidates"] as? [[String: Any]],
                           let first = candidates.first,
                           let content = first["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]],
                           let text = parts.first?["text"] as? String {
                            continuation.yield(ChatStreamChunk(text: text, isComplete: false, error: nil))
                        }

                        // Check for finish
                        if let candidates = json["candidates"] as? [[String: Any]],
                           let first = candidates.first,
                           let finishReason = first["finishReason"] as? String,
                           finishReason == "STOP" {
                            continuation.yield(ChatStreamChunk(text: nil, isComplete: true, error: nil))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(ChatStreamChunk(text: nil, isComplete: false, error: error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Single Message (Non-Streaming)

    /// Sends a single prompt to the AI and returns the full response.
    /// Uses Claude Haiku by default for speed. Falls back to nil on failure.
    func sendSingleMessage(
        prompt: String,
        systemPrompt: String? = nil,
        model: AIModel? = nil
    ) async -> String? {
        let activeModel = model ?? AIModel.allModels.first { $0.id == "claude-haiku-4-5-20251001" } ?? selectedModel

        switch activeModel.provider {
        case .claude:
            return await sendClaudeSingle(prompt: prompt, systemPrompt: systemPrompt, model: activeModel.id)
        case .gemini:
            return await sendGeminiSingle(prompt: prompt, systemPrompt: systemPrompt, model: activeModel.id)
        }
    }

    private func sendClaudeSingle(prompt: String, systemPrompt: String?, model: String) async -> String? {
        do {
            print("[Claude Single] Sending request to model: \(model), key prefix: \(String(anthropicAPIKey.prefix(12)))...")
            let url = URL(string: "https://api.anthropic.com/v1/messages")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anthropicAPIKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            var body: [String: Any] = [
                "model": model,
                "max_tokens": 1024,
                "stream": false,
                "messages": [["role": "user", "content": prompt]]
            ]
            if let systemPrompt {
                body["system"] = systemPrompt
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                print("[Claude Single] No HTTP response")
                return nil
            }
            print("[Claude Single] HTTP status: \(http.statusCode)")
            if http.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
                print("[Claude Single] Error body: \(errorBody)")
                return nil
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let text = content.first?["text"] as? String else {
                let raw = String(data: data, encoding: .utf8) ?? "unparseable"
                print("[Claude Single] JSON parse failed: \(raw.prefix(200))")
                return nil
            }
            print("[Claude Single] Success, response length: \(text.count)")
            return text
        } catch {
            print("[Claude Single] Exception: \(error.localizedDescription)")
            return nil
        }
    }

    private func sendGeminiSingle(prompt: String, systemPrompt: String?, model: String) async -> String? {
        do {
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(geminiAPIKey)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var body: [String: Any] = [
                "contents": [["role": "user", "parts": [["text": prompt]]]],
                "generationConfig": ["maxOutputTokens": 4096, "temperature": 0.3]
            ]
            if let systemPrompt {
                body["systemInstruction"] = ["parts": [["text": systemPrompt]]]
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let first = candidates.first,
                  let content = first["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else { return nil }
            return text
        } catch {
            return nil
        }
    }
}
