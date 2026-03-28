import SwiftUI
import UIKit
import ComposableArchitecture

struct VoiceMemosView: View {
    @Bindable var store: StoreOf<VoiceMemosReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search memos...", text: $store.searchText.sending(\.searchTextChanged))
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if store.filteredMemos.isEmpty && !store.isRecording {
                    emptyState
                } else {
                    memosList
                }
            }
            .navigationTitle("Voice Memos")
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    recordButton
                }
            }
            .sheet(item: Binding(
                get: { store.selectedMemo },
                set: { store.send(.selectMemo($0)) }
            )) { memo in
                MemoDetailSheet(store: store, memo: memo)
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    private var recordButton: some View {
        Button {
            if store.isRecording {
                store.send(.stopRecording)
            } else {
                store.send(.startRecording)
            }
        } label: {
            if store.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                    Text(formattedTime(store.recordingDuration))
                        .font(.caption.monospacedDigit())
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            } else {
                Image(systemName: "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.axisGold)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(Color.axisGold.opacity(0.5))
            Text("No Voice Memos")
                .font(.title2.bold())
            Text("Tap the mic to record and auto-transcribe")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var memosList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Recording indicator
                if store.isRecording {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                            .opacity(store.recordingDuration.truncatingRemainder(dividingBy: 2) < 1 ? 1 : 0.3)
                        VStack(alignment: .leading) {
                            Text("Recording...")
                                .font(.headline)
                            Text(formattedTime(store.recordingDuration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            store.send(.stopRecording)
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Transcribing indicator
                if store.isTranscribing {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Transcribing...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                ForEach(store.filteredMemos) { memo in
                    memoCard(memo)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private func memoCard(_ memo: VoiceMemosReducer.State.MemoItem) -> some View {
        Button {
            store.send(.selectMemo(memo))
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(Color.axisGold)
                    Text(memo.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(memo.formattedDuration)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if memo.isTranscribed && !memo.transcript.hasPrefix("(") {
                    Text(memo.transcript)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !memo.extractedActions.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                            .foregroundStyle(Color.axisGold)
                        Text("\(memo.extractedActions.count) action item\(memo.extractedActions.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(Color.axisGold)
                    }
                }

                Text(memo.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.send(.selectMemo(memo))
            } label: {
                Label("Edit Title", systemImage: "pencil")
            }

            if memo.isTranscribed && !memo.transcript.hasPrefix("(") {
                Button {
                    store.send(.sendToTasks(memo.transcript))
                } label: {
                    Label("Send to Tasks", systemImage: "checklist")
                }

                Button {
                    store.send(.sendToNotes(memo.transcript))
                } label: {
                    Label("Send to Notes", systemImage: "note.text")
                }

                Button {
                    let dateString = memo.createdAt.formatted(date: .long, time: .omitted)
                    let body = "Voice Memo - \(dateString)\n\(memo.transcript)"
                    let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "sms:&body=\(encoded)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Text Transcript", systemImage: "message")
                }

                Button {
                    UIPasteboard.general.string = memo.transcript
                } label: {
                    Label("Copy Transcript", systemImage: "doc.on.doc")
                }
            }

            Button {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let url = docs.appendingPathComponent(memo.audioFileName)
                guard FileManager.default.fileExists(atPath: url.path) else { return }
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    var topVC = rootVC
                    while let presented = topVC.presentedViewController { topVC = presented }
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    topVC.present(activityVC, animated: true)
                }
            } label: {
                Label("Share Audio", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                store.send(.deleteMemo(memo))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.send(.deleteMemo(memo))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formattedTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Detail Sheet

struct MemoDetailSheet: View {
    @Bindable var store: StoreOf<VoiceMemosReducer>
    let memo: VoiceMemosReducer.State.MemoItem
    @State private var editTitle: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    TextField("Title", text: $editTitle)
                        .font(.title2.bold())
                        .onAppear { editTitle = memo.title }
                        .onChange(of: editTitle) { _, newVal in
                            store.send(.updateTitle(id: memo.id, title: newVal))
                        }

                    // Duration & date
                    HStack {
                        Label(memo.formattedDuration, systemImage: "waveform")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(memo.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    // AI Summary
                    if !memo.aiSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Summary", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.axisGold)
                            Text(memo.aiSummary)
                                .font(.body)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.axisGold.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Action Items
                    if !memo.extractedActions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Action Items", systemImage: "checkmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.axisGold)
                            ForEach(memo.extractedActions, id: \.self) { action in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.axisGold)
                                        .padding(.top, 3)
                                    Text(action)
                                        .font(.subheadline)
                                    Spacer()
                                    Menu {
                                        Button {
                                            store.send(.sendToTasks(action))
                                        } label: {
                                            Label("Send to Tasks", systemImage: "checklist")
                                        }
                                        Button {
                                            store.send(.sendToNotes(action))
                                        } label: {
                                            Label("Send to Notes", systemImage: "note.text")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Full Transcript
                    if memo.isTranscribed {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Transcript", systemImage: "text.alignleft")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(memo.transcript)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Memo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    VoiceMemosView(
        store: Store(initialState: VoiceMemosReducer.State()) {
            VoiceMemosReducer()
        }
    )
}
