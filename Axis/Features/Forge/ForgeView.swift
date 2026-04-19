import SwiftUI

struct ForgeView: View {
    @StateObject private var vm = ForgeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    taskInputSection

                    if let error = vm.errorMessage {
                        ErrorBanner(message: error)
                    }

                    if let route = vm.routeResult {
                        RouteResultCard(result: route) {
                            Task { await vm.forgePrompt() }
                        } onOverride: { tool in
                            Task { await vm.forgePrompt(for: tool) }
                        }
                    }

                    if vm.isForging {
                        ProgressView("Forging prompt...")
                            .padding()
                    }

                    if let forge = vm.forgeResult {
                        ForgeResultCard(
                            result: forge,
                            copied: vm.copiedToClipboard,
                            onCopy: { vm.copyPrompt() }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("FORGE")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if vm.routeResult != nil || vm.forgeResult != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Reset") { vm.reset() }
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var taskInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Describe your task")
                .font(.headline)

            TextEditor(text: $vm.taskDescription)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

            Button(action: { Task { await vm.routeTask() } }) {
                HStack {
                    if vm.isRouting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.triangle.branch")
                    }
                    Text(vm.isRouting ? "Analyzing..." : "Route Task")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(vm.canRoute ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!vm.canRoute || vm.isRouting)
        }
    }
}

// MARK: - Subviews

struct RouteResultCard: View {
    let result: RouteResult
    let onForge: () -> Void
    let onOverride: (AITool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: result.aiTool.icon)
                    .font(.title2)
                    .foregroundColor(toolColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use \(result.tool)")
                        .font(.title3.bold())
                    Text("\(Int(result.confidence * 100))% confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Text(result.reasoning)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button(action: onForge) {
                    Label("Forge Prompt for \(result.tool)", systemImage: "hammer.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(toolColor.opacity(0.15))
                        .foregroundColor(toolColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 8) {
                    Text("Override:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(AITool.allCases, id: \.self) { tool in
                        if tool != result.aiTool {
                            Button(tool.rawValue.components(separatedBy: " ").first ?? tool.rawValue) {
                                onOverride(tool)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var toolColor: Color {
        switch result.aiTool {
        case .claudeCLI: return .orange
        case .codexCLI: return .green
        case .cursor: return .blue
        }
    }
}

struct ForgeResultCard: View {
    let result: ForgeResult
    let copied: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Forged Prompt")
                    .font(.headline)
                Spacer()
                Button(action: onCopy) {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline.bold())
                        .foregroundColor(copied ? .green : .accentColor)
                }
            }

            Text(result.optimizedPrompt)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if !result.tips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tips")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    ForEach(result.tips, id: \.self) { tip in
                        Label(tip, systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
