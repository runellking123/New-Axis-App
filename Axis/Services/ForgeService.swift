import Foundation

class ForgeService: ObservableObject {
    private let baseURL = "https://axis-forge-production.up.railway.app"

    func routeTask(description: String) async throws -> RouteResult {
        let data = try await post(endpoint: "/route-task", body: ForgeRequest(description: description, platform: nil))
        return try JSONDecoder().decode(RouteResult.self, from: data)
    }

    func forgePrompt(description: String, platform: String) async throws -> ForgeResult {
        let data = try await post(endpoint: "/forge-prompt", body: ForgeRequest(description: description, platform: platform))
        return try JSONDecoder().decode(ForgeResult.self, from: data)
    }

    private func post<T: Encodable>(endpoint: String, body: T) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw ForgeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ForgeError.serverError("No response from server")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ForgeError.serverError("Server returned \(http.statusCode): \(body)")
        }

        return data
    }
}

enum ForgeError: LocalizedError {
    case invalidURL
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .serverError(let msg): return msg
        }
    }
}
