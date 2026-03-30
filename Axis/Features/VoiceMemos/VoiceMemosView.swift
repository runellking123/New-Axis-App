import SwiftUI
import UIKit
import ComposableArchitecture

// MARK: - Selection Drag Helper

private struct MemoFramePreference: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct VoiceMemosView: View {
    @Bindable var store: StoreOf<VoiceMemosReducer>
    @State private var memoFrames: [UUID: CGRect] = [:]
    @State private var dragSelectedIDs: Set<UUID> = []
    @State private var isDraggingSelection = false

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
                ToolbarItem(placement: .topBarLeading) {
                    if !store.filteredMemos.isEmpty {
                        Button(store.isSelectMode ? "Done" : "Select") {
                            store.send(.toggleSelectMode)
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if store.isSelectMode {
                        Button(store.selectedMemoIDs.count == store.filteredMemos.count ? "Deselect All" : "Select All") {
                            store.send(.selectAll)
                        }
                    } else {
                        recordButton
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if store.isSelectMode && !store.selectedMemoIDs.isEmpty {
                    HStack {
                        Text("\(store.selectedMemoIDs.count) selected")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Button(role: .destructive) {
                            store.send(.deleteSelected)
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
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
        List {
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
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            ForEach(store.filteredMemos) { memo in
                HStack(spacing: 12) {
                    if store.isSelectMode {
                        Image(systemName: store.selectedMemoIDs.contains(memo.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(store.selectedMemoIDs.contains(memo.id) ? Color.axisGold : .secondary)
                            .contentShape(Rectangle().size(width: 44, height: 44))
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: MemoFramePreference.self,
                                        value: [memo.id: geo.frame(in: .named("memoList"))]
                                    )
                                }
                            )
                            .onTapGesture {
                                store.send(.toggleMemoSelection(memo.id))
                            }
                    }
                    memoCard(memo)
                }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.send(.deleteMemo(memo))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .coordinateSpace(name: "memoList")
        .onPreferenceChange(MemoFramePreference.self) { frames in
            memoFrames = frames
        }
        .gesture(
            store.isSelectMode ?
            DragGesture(minimumDistance: 5, coordinateSpace: .named("memoList"))
                .onChanged { value in
                    let location = value.location
                    for (id, frame) in memoFrames {
                        let expandedFrame = frame.insetBy(dx: -20, dy: -8)
                        if expandedFrame.contains(location) {
                            if !dragSelectedIDs.contains(id) {
                                dragSelectedIDs.insert(id)
                                if !store.selectedMemoIDs.contains(id) {
                                    store.send(.toggleMemoSelection(id))
                                }
                            }
                        }
                    }
                    isDraggingSelection = true
                }
                .onEnded { _ in
                    dragSelectedIDs.removeAll()
                    isDraggingSelection = false
                }
            : nil
        )
    }

    private func memoCard(_ memo: VoiceMemosReducer.State.MemoItem) -> some View {
        Button {
            if store.isSelectMode {
                store.send(.toggleMemoSelection(memo.id))
            } else {
                store.send(.selectMemo(memo))
            }
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
                    let body = memo.transcript
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

                Menu {
                    ForEach(WritingStyle.allCases) { style in
                        Button {
                            store.send(.rewriteTranscript(id: memo.id, style: style))
                        } label: {
                            Label(style.rawValue, systemImage: style.icon)
                        }
                    }
                } label: {
                    Label("Rewrite...", systemImage: "pencil.and.outline")
                }

                Button {
                    store.send(.proofreadTranscript(id: memo.id))
                } label: {
                    Label("Proofread", systemImage: "checkmark.circle")
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
    @State private var showingOriginal: Bool = true
    @State private var customTone: String = ""
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
                        .submitLabel(.done)
                        .onSubmit {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

                    // Full Transcript with Original/Rewritten toggle
                    if memo.isTranscribed {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Transcript", systemImage: "text.alignleft")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if !memo.rewrittenTranscript.isEmpty {
                                    Picker("View", selection: $showingOriginal) {
                                        Text("Original").tag(true)
                                        Text("Rewritten").tag(false)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 200)
                                }
                            }

                            if showingOriginal || memo.rewrittenTranscript.isEmpty {
                                Text(memo.transcript)
                                    .font(.body)
                                    .textSelection(.enabled)

                                // Copy & Text for original
                                HStack(spacing: 12) {
                                    Button {
                                        UIPasteboard.general.string = memo.transcript
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button {
                                        let body = memo.transcript
                                        let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                        if let url = URL(string: "sms:&body=\(encoded)") {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        Label("Text", systemImage: "message")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Spacer()
                                }
                                .padding(.top, 4)
                            } else {
                                Text(memo.rewrittenTranscript)
                                    .font(.body)
                                    .textSelection(.enabled)

                                // Copy & Share for rewritten version
                                HStack(spacing: 12) {
                                    Button {
                                        UIPasteboard.general.string = memo.rewrittenTranscript
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button {
                                        let body = memo.rewrittenTranscript
                                        let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                        if let url = URL(string: "sms:&body=\(encoded)") {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        Label("Text", systemImage: "message")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                        }
                    }

                    // Rewrite Options
                    if memo.isTranscribed && !memo.transcript.hasPrefix("(") {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Rewrite", systemImage: "pencil.and.outline")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.axisGold)

                            HStack(spacing: 10) {
                                // Style dropdown
                                Menu {
                                    ForEach(WritingStyle.allCases) { style in
                                        Button {
                                            store.send(.rewriteTranscript(id: memo.id, style: style))
                                            showingOriginal = false
                                        } label: {
                                            Label(style.rawValue, systemImage: style.icon)
                                        }
                                    }
                                } label: {
                                    Label("Style", systemImage: "textformat")
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.axisGold.opacity(0.12))
                                        .foregroundStyle(Color.axisGold)
                                        .clipShape(Capsule())
                                }

                                // Proofread button
                                Button {
                                    store.send(.proofreadTranscript(id: memo.id))
                                    showingOriginal = false
                                } label: {
                                    Label("Proofread", systemImage: "checkmark.circle")
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundStyle(.green)
                                        .clipShape(Capsule())
                                }

                                Spacer()
                            }

                            // Custom tone input
                            HStack(spacing: 8) {
                                TextField("Custom tone (e.g. friendly, urgent, poetic)", text: $customTone)
                                    .font(.subheadline)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button {
                                    guard !customTone.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                    store.send(.rewriteCustomTone(id: memo.id, tone: customTone))
                                    showingOriginal = false
                                } label: {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.axisGold)
                                }
                            }

                            // Loading indicators
                            if store.isRewriting {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Rewriting...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if store.isProofreading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Proofreading...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
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
