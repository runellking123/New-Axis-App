import Foundation
import SwiftUI

@MainActor
class ForgeViewModel: ObservableObject {
    @Published var taskDescription: String = ""
    @Published var routeResult: RouteResult?
    @Published var forgeResult: ForgeResult?
    @Published var isRouting: Bool = false
    @Published var isForging: Bool = false
    @Published var errorMessage: String?
    @Published var copiedToClipboard: Bool = false
    @Published var selectedPlatformOverride: AITool?

    private let service = ForgeService()

    var canRoute: Bool { !taskDescription.trimmingCharacters(in: .whitespaces).isEmpty }

    func routeTask() async {
        guard canRoute else { return }
        isRouting = true
        routeResult = nil
        forgeResult = nil
        errorMessage = nil

        do {
            routeResult = try await service.routeTask(description: taskDescription)
        } catch {
            errorMessage = error.localizedDescription
        }
        isRouting = false
    }

    func forgePrompt(for platform: AITool? = nil) async {
        let targetPlatform = platform ?? routeResult?.aiTool ?? .claudeCLI
        isForging = true
        forgeResult = nil
        errorMessage = nil

        do {
            forgeResult = try await service.forgePrompt(
                description: taskDescription,
                platform: targetPlatform.rawValue
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isForging = false
    }

    func copyPrompt() {
        guard let prompt = forgeResult?.optimizedPrompt else { return }
        UIPasteboard.general.string = prompt
        copiedToClipboard = true

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copiedToClipboard = false
        }
    }

    func reset() {
        taskDescription = ""
        routeResult = nil
        forgeResult = nil
        errorMessage = nil
    }
}
