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
        var selectedMemo: MemoItem? = nil
        var searchText: String = ""

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
        case stopRecording
        case recordingTick
        case recordingCompleted(audioFile: String, duration: Double)
        case transcriptionCompleted(id: UUID, transcript: String)
        case summaryCompleted(id: UUID, summary: String, actions: [String])
        case selectMemo(State.MemoItem?)
        case deleteMemo(State.MemoItem)
        case updateTitle(id: UUID, title: String)
        case sendToTasks(String)
        case sendToNotes(String)
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
                state.isRecording = true
                state.recordingDuration = 0
                let fileName = "voice_memo_\(UUID().uuidString).m4a"
                let url = VoiceMemosReducer.audioURL(for: fileName)
                VoiceRecorder.shared.startRecording(to: url)
                return .run { send in
                    while true {
                        try await clock.sleep(for: .seconds(1))
                        await send(.recordingTick)
                    }
                }.cancellable(id: CancelID.timer)

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
                        State.MemoItem(id: m.uuid, title: m.title, transcript: m.transcript, aiSummary: m.aiSummary, duration: m.duration, audioFileName: m.audioFileName, extractedActions: m.extractedActions, isTranscribed: m.isTranscribed, isSummarized: m.isSummarized, createdAt: m.createdAt)
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

                // Generate summary
                let summary = VoiceMemosReducer.generateSummary(from: transcript)
                let actions = VoiceMemosReducer.extractActions(from: transcript)
                return .send(.summaryCompleted(id: id, summary: summary, actions: actions))

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
                    // Delete audio file
                    let url = VoiceMemosReducer.audioURL(for: match.audioFileName)
                    try? FileManager.default.removeItem(at: url)
                    PersistenceService.shared.deleteVoiceMemo(match)
                }
                state.memos.removeAll { $0.id == memo.id }
                if state.selectedMemo?.id == memo.id {
                    state.selectedMemo = nil
                }
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
                let task = EATask(title: text, category: "personal")
                persistence.saveEATask(task)
                return .none

            case let .sendToNotes(text):
                let note = CapturedNote(content: text)
                persistence.saveNote(note)
                return .none
            }
        }
    }

    private enum CancelID { case timer }

    // MARK: - Helpers

    static func audioURL(for fileName: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    static func transcribeAudio(url: URL) async -> String {
        await withCheckedContinuation { continuation in
            guard SFSpeechRecognizer.authorizationStatus() == .authorized ||
                  SFSpeechRecognizer.authorizationStatus() == .notDetermined else {
                continuation.resume(returning: "(Speech recognition not authorized)")
                return
            }

            SFSpeechRecognizer.requestAuthorization { status in
                guard status == .authorized else {
                    continuation.resume(returning: "(Speech recognition not authorized)")
                    return
                }

                let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
                let request = SFSpeechURLRecognitionRequest(url: url)
                request.shouldReportPartialResults = false

                recognizer?.recognitionTask(with: request) { result, error in
                    if let result = result, result.isFinal {
                        continuation.resume(returning: result.bestTranscription.formattedString)
                    } else if let error = error {
                        continuation.resume(returning: "(Transcription failed: \(error.localizedDescription))")
                    }
                }
            }
        }
    }

    static func generateSummary(from transcript: String) -> String {
        guard !transcript.isEmpty, !transcript.hasPrefix("(") else { return "" }
        let sentences = transcript.components(separatedBy: ". ")
        if sentences.count <= 2 { return transcript }
        let key = sentences.prefix(3).joined(separator: ". ")
        return key + "."
    }

    static func extractActions(from transcript: String) -> [String] {
        guard !transcript.isEmpty, !transcript.hasPrefix("(") else { return [] }
        let keywords = ["need to", "have to", "should", "must", "will", "going to", "want to", "plan to", "remember to", "don't forget"]
        let sentences = transcript.components(separatedBy: ". ")
        var actions: [String] = []
        for sentence in sentences {
            let lower = sentence.lowercased()
            for keyword in keywords {
                if lower.contains(keyword) {
                    let cleaned = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        actions.append(cleaned)
                    }
                    break
                }
            }
        }
        return actions
    }
}

// MARK: - Voice Recorder

final class VoiceRecorder: NSObject, @unchecked Sendable {
    static let shared = VoiceRecorder()
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func startRecording(to url: URL) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recordingURL = url
        recorder?.record()
    }

    func stopRecording() -> (URL, Double)? {
        guard let recorder = recorder else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        let url = recordingURL
        self.recorder = nil
        self.recordingURL = nil
        if let url = url {
            return (url, duration)
        }
        return nil
    }
}
