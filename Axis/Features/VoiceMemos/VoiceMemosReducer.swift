import ComposableArchitecture
import Foundation
import AVFoundation
import Speech

@Reducer
struct VoiceMemosReducer {
    @ObservableState
    struct State: Equatable {
        var memos: [MemoItem] = []
        var isRecording: Bool = false
        var recordingDuration: Double = 0
        var isTranscribing: Bool = false
        var isRewriting: Bool = false
        var isProofreading: Bool = false
        var selectedMemo: MemoItem? = nil
        var searchText: String = ""
        var isSelectMode: Bool = false
        var selectedMemoIDs: Set<UUID> = []
        var playingMemoID: UUID? = nil
        var playbackPosition: Double = 0

        struct MemoItem: Equatable, Identifiable {
            let id: UUID
            var title: String
            var transcript: String
            var aiSummary: String
            var duration: Double
            var audioFileName: String
            var extractedActions: [String]
            var isTranscribed: Bool
            var isSummarized: Bool
            var rewrittenTranscript: String
            var createdAt: Date

            var displayTitle: String {
                if !title.isEmpty { return title }
                if !transcript.isEmpty { return String(transcript.prefix(50)) }
                return "Voice Memo \(createdAt.formatted(date: .abbreviated, time: .shortened))"
            }

            var formattedDuration: String {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
        }

        var filteredMemos: [MemoItem] {
            guard !searchText.isEmpty else { return memos }
            let query = searchText.lowercased()
            return memos.filter {
                $0.title.lowercased().contains(query) ||
                $0.transcript.lowercased().contains(query) ||
                $0.aiSummary.lowercased().contains(query)
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case memosLoaded([State.MemoItem])
        case searchTextChanged(String)
        case startRecording
        case recordingPermissionGranted
        case recordingFailed(String)
        case stopRecording
        case recordingTick
        case recordingCompleted(audioFile: String, duration: Double)
        case deleteAll
        case transcriptionCompleted(id: UUID, transcript: String)
        case polishCompleted(id: UUID, polishedText: String)
        case summaryCompleted(id: UUID, summary: String, actions: [String])
        case rewriteTranscript(id: UUID, style: WritingStyle)
        case rewriteCustomTone(id: UUID, tone: String)
        case rewriteCompleted(id: UUID, rewritten: String)
        case proofreadTranscript(id: UUID)
        case proofreadCompleted(id: UUID, proofread: String)
        case selectMemo(State.MemoItem?)
        case deleteMemo(State.MemoItem)
        case toggleSelectMode
        case toggleMemoSelection(UUID)
        case selectAll
        case deleteSelected
        case updateTitle(id: UUID, title: String)
        case sendToTasks(String)
        case sendToNotes(String)
        case togglePlayback(id: UUID)
        case playbackTick(Double)
        case playbackFinished
        case retryTranscription(id: UUID)
        case skipPlayback(seconds: Double)
        case seekPlayback(to: Double)
    }

    @Dependency(\.axisPersistence) var persistence
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let fetched = PersistenceService.shared.fetchVoiceMemos()
                    let items = fetched.map { memo in
                        State.MemoItem(
                            id: memo.uuid,
                            title: memo.title,
                            transcript: memo.transcript,
                            aiSummary: memo.aiSummary,
                            duration: memo.duration,
                            audioFileName: memo.audioFileName,
                            extractedActions: memo.extractedActions,
                            isTranscribed: memo.isTranscribed,
                            isSummarized: memo.isSummarized,
                            rewrittenTranscript: memo.rewrittenTranscript,
                            createdAt: memo.createdAt
                        )
                    }
                    await send(.memosLoaded(items))
                }

            case let .memosLoaded(items):
                state.memos = items
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case .startRecording:
                // Request mic + speech permission BEFORE starting recorder.
                // Previously record() could fire before iOS granted permission,
                // producing a silent file that SFSpeech reported as "(No speech detected)".
                let fileName = "voice_memo_\(UUID().uuidString).m4a"
                let url = VoiceMemosReducer.audioURL(for: fileName)
                return .run { send in
                    let micGranted = await VoiceRecorder.shared.requestPermission()
                    guard micGranted else {
                        await send(.recordingFailed("Microphone access denied. Enable it in Settings › AXIS."))
                        return
                    }
                    // Pre-warm speech-recognition auth so transcription doesn't block later.
                    _ = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                        SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
                    }
                    guard VoiceRecorder.shared.startRecording(to: url) else {
                        let msg = VoiceRecorder.shared.lastErrorMessage ?? "Recording failed to start."
                        await send(.recordingFailed(msg))
                        return
                    }
                    await send(.recordingPermissionGranted)
                }

            case .recordingPermissionGranted:
                state.isRecording = true
                state.recordingDuration = 0
                return .run { send in
                    while true {
                        try await clock.sleep(for: .seconds(1))
                        await send(.recordingTick)
                    }
                }.cancellable(id: CancelID.timer)

            case let .recordingFailed(message):
                print("[VoiceMemo] Recording failed: \(message)")
                state.isRecording = false
                return .cancel(id: CancelID.timer)

            case .stopRecording:
                state.isRecording = false
                let duration = state.recordingDuration
                if let (url, _) = VoiceRecorder.shared.stopRecording() {
                    let fileName = url.lastPathComponent
                    return .concatenate(
                        .cancel(id: CancelID.timer),
                        .send(.recordingCompleted(audioFile: fileName, duration: duration))
                    )
                }
                return .cancel(id: CancelID.timer)

            case .recordingTick:
                state.recordingDuration += 1
                return .none

            case let .recordingCompleted(audioFile, duration):
                let memo = VoiceMemo(
                    duration: duration,
                    audioFileName: audioFile
                )
                PersistenceService.shared.saveVoiceMemo(memo)
                let memoId = memo.uuid

                // Transcribe
                state.isTranscribing = true
                return .run { send in
                    // Reload list
                    let fetched = PersistenceService.shared.fetchVoiceMemos()
                    let items = fetched.map { m in
                        State.MemoItem(id: m.uuid, title: m.title, transcript: m.transcript, aiSummary: m.aiSummary, duration: m.duration, audioFileName: m.audioFileName, extractedActions: m.extractedActions, isTranscribed: m.isTranscribed, isSummarized: m.isSummarized, rewrittenTranscript: m.rewrittenTranscript, createdAt: m.createdAt)
                    }
                    await send(.memosLoaded(items))

                    // Transcribe audio
                    let url = VoiceMemosReducer.audioURL(for: audioFile)
                    let transcript = await VoiceMemosReducer.transcribeAudio(url: url)
                    await send(.transcriptionCompleted(id: memoId, transcript: transcript))
                }

            case let .transcriptionCompleted(id, transcript):
                state.isTranscribing = false
                // Update in persistence
                let memos = PersistenceService.shared.fetchVoiceMemos()
                if let match = memos.first(where: { $0.uuid == id }) {
                    match.transcript = transcript
                    match.isTranscribed = true
                    PersistenceService.shared.updateVoiceMemos()
                }
                // Update local state
                if let idx = state.memos.firstIndex(where: { $0.id == id }) {
                    state.memos[idx].transcript = transcript
                    state.memos[idx].isTranscribed = true
                }

                // Auto-polish via AI, then generate summary
                let transcriptForPolish = transcript
                return .run { send in
                    let polished = await VoiceMemosReducer.polishTranscript(transcriptForPolish)
                    await send(.polishCompleted(id: id, polishedText: polished))
                }

            case let .polishCompleted(id, polishedText):
                // Update persistence with polished text
                let memos = PersistenceService.shared.fetchVoiceMemos()
                if let match = memos.first(where: { $0.uuid == id }) {
                    match.transcript = polishedText
                    PersistenceService.shared.updateVoiceMemos()
                }
                if let idx = state.memos.firstIndex(where: { $0.id == id }) {
                    state.memos[idx].transcript = polishedText
                }
                // Update selected memo if viewing it
                if state.selectedMemo?.id == id {
                    state.selectedMemo?.transcript = polishedText
                }

                // Extract action items via AI (only if transcript sounds like it has them)
                let textForActions = polishedText
                return .run { send in
                    let actions = await VoiceMemosReducer.extractActionsAI(from: textForActions)
                    await send(.summaryCompleted(id: id, summary: "", actions: actions))
                }

            case let .summaryCompleted(id, summary, actions):
                let memos = PersistenceService.shared.fetchVoiceMemos()
                if let match = memos.first(where: { $0.uuid == id }) {
                    match.aiSummary = summary
                    match.extractedActions = actions
                    match.isSummarized = true
                    PersistenceService.shared.updateVoiceMemos()
                }
                if let idx = state.memos.firstIndex(where: { $0.id == id }) {
                    state.memos[idx].aiSummary = summary
                    state.memos[idx].extractedActions = actions
                    state.memos[idx].isSummarized = true
                }
                return .none

            case let .selectMemo(memo):
                state.selectedMemo = memo
                return .none

            case let .deleteMemo(memo):
                let memos = PersistenceService.shared.fetchVoiceMemos()
                if let match = memos.first(where: { $0.uuid == memo.id }) {
                    let url = VoiceMemosReducer.audioURL(for: match.audioFileName)
                    try? FileManager.default.removeItem(at: url)
                    PersistenceService.shared.deleteVoiceMemo(match)
                }
                state.memos.removeAll { $0.id == memo.id }
                if state.selectedMemo?.id == memo.id {
                    state.selectedMemo = nil
                }
                state.selectedMemoIDs.remove(memo.id)
                return .none

            case .toggleSelectMode:
                state.isSelectMode.toggle()
                if !state.isSelectMode {
                    state.selectedMemoIDs.removeAll()
                }
                return .none

            case let .toggleMemoSelection(id):
                if state.selectedMemoIDs.contains(id) {
                    state.selectedMemoIDs.remove(id)
                } else {
                    state.selectedMemoIDs.insert(id)
                }
                return .none

            case .selectAll:
                if state.selectedMemoIDs.count == state.filteredMemos.count {
                    state.selectedMemoIDs.removeAll()
                } else {
                    state.selectedMemoIDs = Set(state.filteredMemos.map(\.id))
                }
                return .none

            case .deleteAll:
                let stored = PersistenceService.shared.fetchVoiceMemos()
                for memo in stored {
                    let url = VoiceMemosReducer.audioURL(for: memo.audioFileName)
                    try? FileManager.default.removeItem(at: url)
                    PersistenceService.shared.deleteVoiceMemo(memo)
                }
                state.memos.removeAll()
                state.selectedMemo = nil
                state.selectedMemoIDs.removeAll()
                state.isSelectMode = false
                return .none

            case .deleteSelected:
                let idsToDelete = state.selectedMemoIDs
                let memos = PersistenceService.shared.fetchVoiceMemos()
                for id in idsToDelete {
                    if let match = memos.first(where: { $0.uuid == id }) {
                        let url = VoiceMemosReducer.audioURL(for: match.audioFileName)
                        try? FileManager.default.removeItem(at: url)
                        PersistenceService.shared.deleteVoiceMemo(match)
                    }
                }
                state.memos.removeAll { idsToDelete.contains($0.id) }
                if let selected = state.selectedMemo, idsToDelete.contains(selected.id) {
                    state.selectedMemo = nil
                }
                state.selectedMemoIDs.removeAll()
                state.isSelectMode = false
                return .none

            case let .updateTitle(id, title):
                let memos = PersistenceService.shared.fetchVoiceMemos()
                if let match = memos.first(where: { $0.uuid == id }) {
                    match.title = title
                    PersistenceService.shared.updateVoiceMemos()
                }
                if let idx = state.memos.firstIndex(where: { $0.id == id }) {
                    state.memos[idx].title = title
                }
                return .none

            case let .sendToTasks(text):
                // "Send to Tasks" now creates an iOS Reminder since the Tasks
                // feature has been folded into Reminders. Action name is kept
                // so existing UI strings and action chips do not break.
                _ = CalendarService.shared.createReminder(title: text)
                return .none

            case let .sendToNotes(text):
                let note = CapturedNote(content: text)
                persistence.saveNote(note)
                return .none

            case let .togglePlayback(id):
                if state.playingMemoID == id {
                    MemoAudioPlayer.shared.stop()
                    state.playingMemoID = nil
                    state.playbackPosition = 0
                    return .cancel(id: CancelID.playback)
                }
                guard let memo = state.memos.first(where: { $0.id == id }) else { return .none }
                let url = VoiceMemosReducer.audioURL(for: memo.audioFileName)
                guard FileManager.default.fileExists(atPath: url.path) else { return .none }
                let started = MemoAudioPlayer.shared.play(url: url) {
                    Task { @MainActor in
                        // Sent via notification below
                        NotificationCenter.default.post(name: .axisMemoPlaybackFinished, object: nil)
                    }
                }
                guard started else { return .none }
                state.playingMemoID = id
                state.playbackPosition = 0
                return .merge(
                    .run { send in
                        while true {
                            try await clock.sleep(for: .milliseconds(200))
                            await send(.playbackTick(MemoAudioPlayer.shared.currentTime))
                        }
                    }.cancellable(id: CancelID.playback),
                    .publisher {
                        NotificationCenter.default.publisher(for: .axisMemoPlaybackFinished)
                            .map { _ in Action.playbackFinished }
                    }.cancellable(id: CancelID.playbackFinish)
                )

            case let .playbackTick(position):
                state.playbackPosition = position
                return .none

            case .playbackFinished:
                state.playingMemoID = nil
                state.playbackPosition = 0
                return .merge(
                    .cancel(id: CancelID.playback),
                    .cancel(id: CancelID.playbackFinish)
                )

            case let .skipPlayback(seconds):
                guard state.playingMemoID != nil else { return .none }
                let target = max(0, MemoAudioPlayer.shared.currentTime + seconds)
                MemoAudioPlayer.shared.seek(to: target)
                state.playbackPosition = MemoAudioPlayer.shared.currentTime
                return .none

            case let .seekPlayback(target):
                guard state.playingMemoID != nil else { return .none }
                MemoAudioPlayer.shared.seek(to: max(0, target))
                state.playbackPosition = MemoAudioPlayer.shared.currentTime
                return .none

            case let .retryTranscription(id):
                guard let memo = state.memos.first(where: { $0.id == id }) else { return .none }
                let audioFile = memo.audioFileName
                state.isTranscribing = true
                return .run { send in
                    let url = VoiceMemosReducer.audioURL(for: audioFile)
                    let transcript = await VoiceMemosReducer.transcribeAudio(url: url)
                    await send(.transcriptionCompleted(id: id, transcript: transcript))
                }

            case let .rewriteTranscript(id, style):
                state.isRewriting = true
                let transcript: String
                if let idx = state.memos.firstIndex(where: { $0.id == id }) {
                    transcript = state.memos[idx].transcript
                } else {
                    return .none
                }
                return .run { send in
                    let rewritten = await VoiceMemosReducer.rewriteTranscript(transcript, style: style)
                    await send(.rewriteCompleted(id: id, rewritten: rewritten))
                }

            case let .rewriteCustomTone(id, tone):
                state.isRewriting = true
                let transcript: String
                if let idx = state.memos.firstIndex(where: { $0.id == id }) {
                    transcript = state.memos[idx].transcript
                } else {
                    return .none
                }
                return .run { send in
                    let rewritten = await VoiceMemosReducer.rewriteWithCustomTone(transcript, tone: tone)
                    await send(.rewriteCompleted(id: id, rewritten: rewritten))
                }

            case let .rewriteCompleted(id, rewritten):
                state.isRewriting = false
                let memos = PersistenceService.shared.fetchVoiceMemos()
                if let match = memos.first(where: { $0.uuid == id }) {
                    match.rewrittenTranscript = rewritten
                    PersistenceService.shared.updateVoiceMemos()
                }
                if let idx = state.memos.firstIndex(where: { $0.id == id }) {
                    state.memos[idx].rewrittenTranscript = rewritten
                }
                if state.selectedMemo?.id == id {
                    state.selectedMemo?.rewrittenTranscript = rewritten
                }
                return .none

            case let .proofreadTranscript(id):
                state.isProofreading = true
                let transcript: String
                if let idx = state.memos.firstIndex(where: { $0.id == id }) {
                    transcript = state.memos[idx].transcript
                } else {
                    return .none
                }
                return .run { send in
                    let proofread = await VoiceMemosReducer.proofreadTranscript(transcript)
                    await send(.proofreadCompleted(id: id, proofread: proofread))
                }

            case let .proofreadCompleted(id, proofread):
                state.isProofreading = false
                let memos = PersistenceService.shared.fetchVoiceMemos()
                if let match = memos.first(where: { $0.uuid == id }) {
                    match.rewrittenTranscript = proofread
                    PersistenceService.shared.updateVoiceMemos()
                }
                if let idx = state.memos.firstIndex(where: { $0.id == id }) {
                    state.memos[idx].rewrittenTranscript = proofread
                }
                if state.selectedMemo?.id == id {
                    state.selectedMemo?.rewrittenTranscript = proofread
                }
                return .none
            }
        }
    }

    private enum CancelID { case timer, playback, playbackFinish }

    // MARK: - Helpers

    static func audioURL(for fileName: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    static func transcribeAudio(url: URL) async -> String {
        print("[Transcribe] Start url=\(url.lastPathComponent) exists=\(FileManager.default.fileExists(atPath: url.path))")
        // Give AVAudioRecorder a moment to flush the final encoded frames.
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return "(Audio file missing)"
        }
        let fileSize = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int) ?? 0
        print("[Transcribe] File size: \(fileSize) bytes")
        // ~2KB is an empty AAC container with no captured audio. Surface a clearer
        // message than "(No speech detected)" which misleads the user into thinking
        // they didn't speak loudly enough.
        if fileSize < 4_000 {
            return "(Recording captured no audio — check that AXIS has microphone permission in Settings.)"
        }

        // Ensure speech recognition is authorized.
        let authStatus = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        print("[Transcribe] Auth status rawValue=\(authStatus.rawValue)")
        guard authStatus == .authorized else {
            return "(Speech recognition not authorized — enable in Settings › Privacy › Speech Recognition)"
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            return "(Speech recognizer unavailable — locale unsupported)"
        }
        print("[Transcribe] Recognizer isAvailable=\(recognizer.isAvailable) supportsOnDevice=\(recognizer.supportsOnDeviceRecognition)")
        guard recognizer.isAvailable else {
            return "(Speech recognizer unavailable — check network/device)"
        }

        // Prefer server recognition in bounded chunks. Whole-file on-device recognition
        // can produce a non-empty but truncated final result for longer memo files.
        let serverResult = await transcribeChunked(url: url, recognizer: recognizer, onDevice: false)
        if !serverResult.isEmpty {
            print("[Transcribe] Server chunking succeeded: \(serverResult.prefix(120))")
            return serverResult
        }

        if recognizer.supportsOnDeviceRecognition {
            print("[Transcribe] Server returned empty, trying chunked on-device fallback")
            let onDeviceResult = await transcribeChunked(url: url, recognizer: recognizer, onDevice: true)
            if !onDeviceResult.isEmpty {
                print("[Transcribe] On-device chunking succeeded: \(onDeviceResult.prefix(120))")
                return onDeviceResult
            }
        }

        let final = "(No speech detected)"
        print("[Transcribe] Finish: \(final.prefix(120))")
        return final
    }

    /// Splits audio longer than 50 seconds into chunks so server-based
    /// recognition can handle the full recording (Apple caps server requests
    /// at roughly 1 minute of audio).
    private static func transcribeChunked(url: URL, recognizer: SFSpeechRecognizer, onDevice: Bool) async -> String {
        let asset = AVURLAsset(url: url)
        let totalSeconds: Double
        do {
            let duration = try await asset.load(.duration)
            totalSeconds = CMTimeGetSeconds(duration)
        } catch {
            print("[Transcribe] Could not load duration, trying single request")
            return await runSingleRecognition(url: url, recognizer: recognizer, onDevice: onDevice, timeout: onDevice ? 120 : 600)
        }
        print("[Transcribe] Audio duration: \(totalSeconds)s")

        // Short audio — single request is fine.
        guard totalSeconds > 50 else {
            return await runSingleRecognition(url: url, recognizer: recognizer, onDevice: onDevice, timeout: onDevice ? 120 : 600)
        }

        // Chunk into ~50-second segments.
        let chunkSeconds: Double = 50
        var transcripts: [String] = []
        var start: Double = 0
        var chunkIndex = 0

        while start < totalSeconds {
            let end = min(start + chunkSeconds, totalSeconds)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("axis_chunk_\(chunkIndex)_\(UUID().uuidString).m4a")

            print("[Transcribe] Chunk \(chunkIndex): \(String(format: "%.1f", start))s–\(String(format: "%.1f", end))s")
            if await exportAudioChunk(from: url, to: tempURL, startSeconds: start, endSeconds: end) {
                let result = await runSingleRecognition(url: tempURL, recognizer: recognizer, onDevice: onDevice, timeout: 120)
                if !result.isEmpty && !result.hasPrefix("(") {
                    transcripts.append(result)
                }
            }

            try? FileManager.default.removeItem(at: tempURL)
            start = end
            chunkIndex += 1
        }

        print("[Transcribe] Chunked transcription: \(transcripts.count)/\(chunkIndex) chunks succeeded")
        return transcripts.joined(separator: " ")
    }

    /// Exports a time-range slice of an audio file to a new M4A file.
    private static func exportAudioChunk(from source: URL, to dest: URL, startSeconds: Double, endSeconds: Double) async -> Bool {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            print("[Transcribe] Could not create export session")
            return false
        }
        let startTime = CMTime(seconds: startSeconds, preferredTimescale: 44100)
        let endTime = CMTime(seconds: endSeconds, preferredTimescale: 44100)
        session.timeRange = CMTimeRange(start: startTime, end: endTime)
        session.outputURL = dest
        session.outputFileType = .m4a
        await session.export()
        if session.status != .completed {
            print("[Transcribe] Export chunk failed: \(session.error?.localizedDescription ?? "unknown")")
        }
        return session.status == .completed
    }

    /// Runs a single speech recognition attempt. Returns the transcript text,
    /// or an empty string if recognition produced no usable result (so the
    /// caller can try a different strategy).
    private static func runSingleRecognition(url: URL, recognizer: SFSpeechRecognizer, onDevice: Bool, timeout: TimeInterval) async -> String {
        let label = onDevice ? "OnDevice" : "Server"
        return await withCheckedContinuation { continuation in
            let resumed = TranscriptionResumeGuard()
            func finish(_ value: String) {
                guard resumed.claim() else { return }
                continuation.resume(returning: value)
            }

            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            request.requiresOnDeviceRecognition = onDevice
            let accumulator = TranscriptionResultAccumulator()

            let task = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    print("[Transcribe] \(label) error: \(error)")
                    if let best = accumulator.best {
                        finish(best)
                        return
                    }
                    if onDevice {
                        finish("")  // Empty signals caller to try server fallback
                    } else {
                        finish("(Transcription failed: \(error.localizedDescription))")
                    }
                    return
                }
                if let result {
                    let text = result.bestTranscription.formattedString
                    accumulator.record(text)
                    if result.isFinal {
                        let finalText = accumulator.best ?? text
                        print("[Transcribe] \(label) final: \(finalText.prefix(120))")
                        finish(finalText)
                    }
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                print("[Transcribe] \(label) timeout after \(Int(timeout))s")
                task.cancel()
                if let best = accumulator.best {
                    finish(best)
                    return
                }
                if onDevice {
                    finish("")
                } else {
                    finish("(Transcription timed out)")
                }
            }
        }
    }

    static func extractActionsAI(from transcript: String) async -> [String] {
        guard !transcript.isEmpty, !transcript.hasPrefix("(") else { return [] }
        let prompt = """
        Read this voice memo transcript and determine if it contains any genuine \
        action items, tasks, reminders, or things the speaker needs to do. \
        Only extract items that are clearly actionable — things like "I need to...", \
        "remind me to...", "don't forget to...", "I have to...", deadlines, or \
        commitments. Do NOT extract casual observations, opinions, or general statements.

        If there are NO action items, respond with exactly: NONE

        If there ARE action items, list each one on its own line with no bullets, \
        numbers, or prefixes. Just the action item text.

        Transcript:
        \(transcript)
        """
        if let result = await MultiProviderChatService.shared.sendSingleMessage(
            prompt: prompt,
            systemPrompt: "You extract action items from transcripts. Be selective — only flag genuine tasks and reminders, not every sentence."
        ) {
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.uppercased() == "NONE" || trimmed.isEmpty { return [] }
            return trimmed.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    // MARK: - AI Text Processing

    static func polishTranscript(_ text: String) async -> String {
        guard !text.isEmpty, !text.hasPrefix("(") else {
            print("[VoiceMemo Polish] Skipped: text empty or starts with '('")
            return text
        }
        print("[VoiceMemo Polish] Starting AI polish for: \(text.prefix(80))...")
        let prompt = """
        Clean up this speech-to-text transcription. Fix grammar, punctuation, spelling, \
        and sentence structure so it reads naturally. Keep the original meaning and ALL \
        words intact — do not add, remove, censor, or rephrase content. Preserve all \
        explicit language, slang, and colloquial speech exactly as spoken. If the speaker \
        says a word, keep that exact word. Return only the corrected text with no extra commentary.

        Transcription:
        \(text)
        """
        if let polished = await MultiProviderChatService.shared.sendSingleMessage(
            prompt: prompt,
            systemPrompt: "You are a transcription editor. Return only the corrected text. Never censor, remove, or replace any words including explicit language, profanity, or slang. Preserve the speaker's exact vocabulary."
        ) {
            let trimmed = polished.trimmingCharacters(in: .whitespacesAndNewlines)
            if looksSubstantiallyTruncated(original: text, candidate: trimmed) {
                print("[VoiceMemo Polish] Rejected truncated AI output; keeping raw transcript")
                return text
            }
            print("[VoiceMemo Polish] AI success: \(trimmed.prefix(80))...")
            return trimmed
        }
        print("[VoiceMemo Polish] AI failed, using fallback grammar correction")
        // Fallback to rule-based correction
        return SpeechService.correctGrammar(text)
    }

    private static func looksSubstantiallyTruncated(original: String, candidate: String) -> Bool {
        let originalWords = wordCount(in: original)
        let candidateWords = wordCount(in: candidate)
        guard originalWords >= 20 else { return candidateWords == 0 }
        return candidateWords < Int(Double(originalWords) * 0.85)
    }

    private static func wordCount(in text: String) -> Int {
        text.split { !$0.isLetter && !$0.isNumber }.count
    }

    static func rewriteTranscript(_ text: String, style: WritingStyle) async -> String {
        guard !text.isEmpty else { return text }
        let prompt = """
        Rewrite the following text in a \(style.promptDescription) style. \
        Keep all the original information and meaning. Return only the rewritten text \
        with no extra commentary. Do NOT use asterisks, markdown, bold, or any special formatting. \
        Use plain text only with dashes for lists.

        Text:
        \(text)
        """
        if let rewritten = await MultiProviderChatService.shared.sendSingleMessage(
            prompt: prompt,
            systemPrompt: "You are a professional writing assistant. Return only plain text with no markdown or asterisks.",
            model: AIModel.allModels.first { $0.id == "claude-haiku-4-5-20251001" }
        ) {
            return stripAsterisks(rewritten.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return text
    }

    static func rewriteWithCustomTone(_ text: String, tone: String) async -> String {
        guard !text.isEmpty, !tone.isEmpty else { return text }
        let prompt = """
        Rewrite the following text with this tone/style: \(tone). \
        Keep all the original information and meaning. Return only the rewritten text \
        with no extra commentary. Do NOT use asterisks, markdown, bold, or any special formatting. \
        Use plain text only.

        Text:
        \(text)
        """
        if let rewritten = await MultiProviderChatService.shared.sendSingleMessage(
            prompt: prompt,
            systemPrompt: "You are a professional writing assistant. Return only plain text with no markdown or asterisks.",
            model: AIModel.allModels.first { $0.id == "claude-haiku-4-5-20251001" }
        ) {
            return stripAsterisks(rewritten.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return text
    }

    private static func stripAsterisks(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "# ", with: "")
    }

    static func proofreadTranscript(_ text: String) async -> String {
        guard !text.isEmpty else { return text }
        let prompt = """
        Proofread the following text. Fix any grammar, spelling, punctuation, or \
        syntax errors. If the text is already correct, return it unchanged. \
        Return ONLY the corrected text with no extra commentary, no list of changes, \
        and no explanations. Do NOT use asterisks, markdown, bold, or any special formatting. \
        Use plain text only.

        Text:
        \(text)
        """
        if let proofread = await MultiProviderChatService.shared.sendSingleMessage(
            prompt: prompt,
            systemPrompt: "You are a meticulous proofreader. Return only the corrected plain text, nothing else."
        ) {
            return stripAsterisks(proofread.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return text
    }
}

// MARK: - Writing Style

enum WritingStyle: String, CaseIterable, Equatable, Identifiable {
    case professional = "Professional"
    case casual = "Casual"
    case academic = "Academic"
    case concise = "Concise"
    case email = "Email"
    case meetingNotes = "Meeting Notes"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .professional: return "briefcase"
        case .casual: return "face.smiling"
        case .academic: return "graduationcap"
        case .concise: return "list.bullet"
        case .email: return "envelope"
        case .meetingNotes: return "doc.text"
        }
    }

    var promptDescription: String {
        switch self {
        case .professional:
            return "professional and formal business"
        case .casual:
            return "casual and conversational"
        case .academic:
            return "academic and scholarly"
        case .concise:
            return "concise bullet-point summary, extracting only the key takeaways"
        case .email:
            return "well-formatted email ready to send, with a subject line, greeting, body, and sign-off"
        case .meetingNotes:
            return "structured meeting minutes with attendees (if mentioned), discussion points, decisions, and action items"
        }
    }
}

// MARK: - Voice Recorder

final class VoiceRecorder: NSObject, AVAudioRecorderDelegate, @unchecked Sendable {
    static let shared = VoiceRecorder()
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private(set) var lastErrorMessage: String?

    func requestPermission() async -> Bool {
        #if os(iOS)
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        return await AVAudioApplication.requestRecordPermission()
        #else
        return true
        #endif
    }

    @discardableResult
    func startRecording(to url: URL) -> Bool {
        lastErrorMessage = nil

        #if os(iOS)
        // `.record` + `.measurement` is Apple's recommended combination for speech
        // capture. The previous `.playAndRecord` with `.defaultToSpeaker` rerouted
        // the mic on some devices and produced silent files that SFSpeech reported
        // as "(No speech detected)".
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastErrorMessage = "Audio session error: \(error.localizedDescription)"
            print("[VoiceRecorder] \(lastErrorMessage!)")
            return false
        }
        #endif

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.delegate = self
            r.isMeteringEnabled = true
            guard r.prepareToRecord() else {
                lastErrorMessage = "Could not prepare recorder (check disk space / file path)."
                print("[VoiceRecorder] \(lastErrorMessage!)")
                return false
            }
            guard r.record() else {
                lastErrorMessage = "Recorder.record() returned false — microphone in use or permission not granted."
                print("[VoiceRecorder] \(lastErrorMessage!)")
                return false
            }
            recorder = r
            recordingURL = url
            print("[VoiceRecorder] Recording started → \(url.lastPathComponent)")
            return true
        } catch {
            lastErrorMessage = "Recorder init failed: \(error.localizedDescription)"
            print("[VoiceRecorder] \(lastErrorMessage!)")
            return false
        }
    }

    func stopRecording() -> (URL, Double)? {
        guard let recorder = recorder else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        let url = recordingURL
        self.recorder = nil
        self.recordingURL = nil
        #if os(iOS)
        // Release so SFSpeechRecognizer has exclusive access.
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
        if let url = url {
            let size = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int) ?? 0
            print("[VoiceRecorder] Stopped. duration=\(duration)s size=\(size)B")
            return (url, duration)
        }
        return nil
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            print("[VoiceRecorder] Encode error: \(error)")
            lastErrorMessage = "Encoding error: \(error.localizedDescription)"
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("[VoiceRecorder] didFinish success=\(flag)")
    }
}

// MARK: - Memo Audio Player

extension Notification.Name {
    static let axisMemoPlaybackFinished = Notification.Name("AxisMemoPlaybackFinished")
}

final class TranscriptionResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

final class TranscriptionResultAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var bestText = ""

    var best: String? {
        lock.lock(); defer { lock.unlock() }
        return bestText.isEmpty ? nil : bestText
    }

    func record(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        if trimmed.count > bestText.count {
            bestText = trimmed
        }
        lock.unlock()
    }
}

final class MemoAudioPlayer: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    static let shared = MemoAudioPlayer()
    private var player: AVAudioPlayer?
    private var onFinish: (() -> Void)?

    var currentTime: Double { player?.currentTime ?? 0 }
    var isPlaying: Bool { player?.isPlaying ?? false }

    func play(url: URL, onFinish: @escaping () -> Void) -> Bool {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        try? session.overrideOutputAudioPort(.speaker)
        try? session.setActive(true)
        #endif

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            guard p.play() else { return false }
            self.player = p
            self.onFinish = onFinish
            return true
        } catch {
            print("[MemoAudioPlayer] play failed: \(error)")
            return false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        onFinish = nil
    }

    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        let cb = onFinish
        onFinish = nil
        cb?()
    }
}
