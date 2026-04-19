import Foundation

enum AITool: String, Codable, CaseIterable {
    case claudeCLI = "Claude CLI"
    case codexCLI = "Codex CLI"
    case cursor = "Cursor"

    var icon: String {
        switch self {
        case .claudeCLI: return "terminal.fill"
        case .codexCLI: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursorarrow.rays"
        }
    }

    var color: String {
        switch self {
        case .claudeCLI: return "orange"
        case .codexCLI: return "green"
        case .cursor: return "blue"
        }
    }
}

struct RouteResult: Codable {
    let tool: String
    let reasoning: String
    let confidence: Double

    var aiTool: AITool {
        AITool(rawValue: tool) ?? .claudeCLI
    }
}

struct ForgeResult: Codable {
    let optimizedPrompt: String
    let platform: String
    let tips: [String]

    enum CodingKeys: String, CodingKey {
        case optimizedPrompt = "optimized_prompt"
        case platform
        case tips
    }
}

struct ForgeRequest: Codable {
    let description: String
    let platform: String?
}
