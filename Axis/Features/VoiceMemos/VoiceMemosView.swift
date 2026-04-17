import SwiftUI
#if os(iOS)
import UIKit
#endif
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
    @State private var showDeleteAllConfirm = false

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
                        Menu {
                            Button {
                                store.send(.toggleSelectMode)
                            } label: {
                                Label(store.isSelectMode ? "Exit Select" : "Select", systemImage: "checkmark.circle")
                            }
                            Button {
                                store.send(.selectAll)
                                if !store.isSelectMode { store.send(.toggleSelectMode) }
                            } label: {
                                Label("Select All", systemImage: "checkmark.circle.fill")
                            }
                            Divider()
                            Button(role: .destructive) {
                                showDeleteAllConfirm = true
                            } label: {
                                Label("Delete All Memos", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if store.isSelectMode {
                        HStack(spacing: 8) {
                            Button(store.selectedMemoIDs.count == store.filteredMemos.count ? "Deselect All" : "Select All") {
                                store.send(.selectAll)
                            }
                            Button("Done") {
                                store.send(.toggleSelectMode)
                            }
                        }
                    } else {
                        recordButton
                    }
                }
            }
            .confirmationDialog(
                "Delete all \(store.memos.count) memo\(store.memos.count == 1 ? "" : "s")?",
                isPresented: $showDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    store.send(.deleteAll)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all recordings and transcripts. This cannot be undone.")
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
                    HStack(spacing: AxisSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.axisAccent)
                        Text("\(memo.extractedActions.count) action item\(memo.extractedActions.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
                    Label("Send to Reminders", systemImage: "checklist")
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
                        PlatformServices.openURL(url)
                    }
                } label: {
                    Label("Text Transcript", systemImage: "message")
                }

                Button {
                    PlatformServices.copyToClipboard(memo.transcript)
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
                PlatformServices.share(items: [url])
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

    private var isPlayingThisMemo: Bool {
        store.playingMemoID == memo.id
    }

    private var playbackControls: some View {
        let progress = memo.duration > 0 ? min(store.playbackPosition / memo.duration, 1.0) : 0
        return VStack(spacing: 12) {
            // Scrubber
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                        Capsule()
                            .fill(Color.axisGold)
                            .frame(width: max(0, geo.size.width * progress))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard memo.duration > 0, isPlayingThisMemo else { return }
                                let pct = max(0, min(1, value.location.x / geo.size.width))
                                store.send(.seekPlayback(to: pct * memo.duration))
                            }
                    )
                }
                .frame(height: 6)

                HStack {
                    Text(formatTime(store.playbackPosition))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(memo.formattedDuration)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            // Transport controls
            HStack(spacing: 36) {
                Button {
                    store.send(.skipPlayback(seconds: -15))
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28))
                        .foregroundStyle(isPlayingThisMemo ? Color.axisGold : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!isPlayingThisMemo)

                Button {
                    store.send(.togglePlayback(id: memo.id))
                } label: {
                    Image(systemName: isPlayingThisMemo ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.axisGold)
                }
                .buttonStyle(.plain)

                Button {
                    store.send(.skipPlayback(seconds: 15))
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28))
                        .foregroundStyle(isPlayingThisMemo ? Color.axisGold : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!isPlayingThisMemo)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatTime(_ s: Double) -> String {
        let m = Int(s) / 60
        let sec = Int(s) % 60
        return String(format: "%d:%02d", m, sec)
    }

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
                            PlatformServices.dismissKeyboard()
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

                    // Playback
                    playbackControls

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
                                            Label("Send to Reminders", systemImage: "checklist")
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

                    // Retry transcription if it failed (transcript starts with "(")
                    if memo.isTranscribed && memo.transcript.hasPrefix("(") {
                        Button {
                            store.send(.retryTranscription(id: memo.id))
                        } label: {
                            HStack {
                                if store.isTranscribing {
                                    ProgressView().controlSize(.small)
                                    Text("Transcribing...")
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry Transcription")
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.axisGold.opacity(0.15))
                            .foregroundStyle(Color.axisGold)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isTranscribing)
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
                                        PlatformServices.copyToClipboard(memo.transcript)
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
                                            PlatformServices.openURL(url)
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
                                        PlatformServices.copyToClipboard(memo.rewrittenTranscript)
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
                                            PlatformServices.openURL(url)
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
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            shareMemo(includeAudio: true, includeTranscript: true)
                        } label: {
                            Label("Share Audio + Transcript", systemImage: "waveform.badge.plus")
                        }
                        Button {
                            shareMemo(includeAudio: false, includeTranscript: true)
                        } label: {
                            Label("Share Transcript Only", systemImage: "text.alignleft")
                        }
                        Button {
                            shareMemo(includeAudio: true, includeTranscript: false)
                        } label: {
                            Label("Share Audio Only", systemImage: "waveform")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func shareMemo(includeAudio: Bool, includeTranscript: Bool) {
        var items: [Any] = []
        if includeTranscript {
            let text = !memo.rewrittenTranscript.isEmpty && !showingOriginal
                ? memo.rewrittenTranscript
                : memo.transcript
            if !text.isEmpty && !text.hasPrefix("(") {
                let header = memo.displayTitle
                items.append("\(header)\n\n\(text)")
            }
        }
        if includeAudio {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = docs.appendingPathComponent(memo.audioFileName)
            if FileManager.default.fileExists(atPath: url.path) {
                items.append(url)
            }
        }
        guard !items.isEmpty else { return }
        PlatformServices.share(items: items)
    }
}

#Preview {
    VoiceMemosView(
        store: Store(initialState: VoiceMemosReducer.State()) {
            VoiceMemosReducer()
        }
    )
}
