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
        AIModel(id: "gemini-2.5-pro-preview-06-05", displayName: "Gemini 2.5 Pro", provider: .gemini),
        AIModel(id: "gemini-2.5-flash-preview-05-20", displayName: "Gemini 2.5 Flash", provider: .gemini),
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

    var anthropicAPIKey: String {
        get { UserDefaults.standard.string(forKey: "anthropic_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "anthropic_api_key") }
    }
    var geminiAPIKey: String {
        get { UserDefaults.standard.string(forKey: "gemini_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "gemini_api_key") }
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
    You are AXIS, an AI-powered executive assistant for Dr. Runell King, \
    Vice President for Institutional Research, Effectiveness & Strategic Retention \
    at Wiley University (HBCU).

    ROLE CONTEXT:
    Dr. King leads institutional research, data analytics, and strategic retention \
    initiatives at Wiley University. He also runs IR Analytics Consulting serving HBCU clients.

    ACTIVE PROJECTS:
    1. SACSCOC 2029 Reaffirmation Preparation
    2. IPEDS Reporting (federal compliance)
    3. WileyAnalytics iOS App (enrollment, retention, academics dashboard)
    4. HTAnalytics v2 (Huston-Tillotson dashboard with Blackbaud integration)
    5. Blackbaud SKY API integration for donor/alumni analytics

    KEY PRIORITIES:
    1. Strategic enrollment management and retention analytics
    2. Accreditation compliance and institutional effectiveness
    3. Data-informed decision making for HBCU leadership
    4. Building iOS tools that put institutional data at administrators' fingertips

    COMMUNICATION STYLE:
    - Executive-level: concise, data-driven, actionable
    - Prefer bullet points and structured outputs over long prose
    - Use specific metrics and numbers when available
    - Frame recommendations in terms of impact on enrollment, retention, and compliance

    DATA ACCESS:
    When the user asks about their data, tasks, projects, or schedule, you can reference the context provided. Be specific with numbers and details when available.

    RESPONSE FORMAT:
    - Keep ALL responses under 150 words
    - Use plain text only. Never use asterisks, markdown, bold, or special formatting
    - Use dashes for lists, not bullets or asterisks
    - Write in natural, conversational sentences with proper grammar
    - No filler words or unnecessary preamble
    - Get straight to the answer
    - Only elaborate if explicitly asked
    """

    // MARK: - Streaming Chat

    func streamChat(
        messages: [(role: String, content: String)],
        model: AIModel? = nil
    ) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        let activeModel = model ?? selectedModel
        switch activeModel.provider {
        case .claude:
            return streamClaude(messages: messages, model: activeModel.id)
        case .gemini:
            return streamGemini(messages: messages, model: activeModel.id)
        }
    }

    // MARK: - Claude (Anthropic Messages API)

    private func streamClaude(
        messages: [(role: String, content: String)],
        model: String
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

                    let msgArray = messages.map { ["role": $0.role, "content": $0.content] }
                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 1024,
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
}
