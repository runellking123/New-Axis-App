import Foundation
import SwiftData

@Model
final class VoiceMemo {
    var uuid: UUID = UUID()
    var title: String = ""
    var transcript: String = ""
    var aiSummary: String = ""
    var duration: Double = 0
    var audioFileName: String = ""
    var extractedActions: [String] = []
    var isTranscribed: Bool = false
    var isSummarized: Bool = false
    var rewrittenTranscript: String = ""
    var createdAt: Date = Date()

    init(
        title: String = "",
        transcript: String = "",
        aiSummary: String = "",
        duration: Double = 0,
        audioFileName: String = "",
        extractedActions: [String] = [],
        isTranscribed: Bool = false,
        isSummarized: Bool = false,
        rewrittenTranscript: String = ""
    ) {
        self.uuid = UUID()
        self.title = title
        self.transcript = transcript
        self.aiSummary = aiSummary
        self.duration = duration
        self.audioFileName = audioFileName
        self.extractedActions = extractedActions
        self.isTranscribed = isTranscribed
        self.isSummarized = isSummarized
        self.rewrittenTranscript = rewrittenTranscript
        self.createdAt = Date()
    }

    var displayTitle: String {
        if !title.isEmpty { return title }
        if !transcript.isEmpty {
            return String(transcript.prefix(50))
        }
        return "Voice Memo \(createdAt.formatted(date: .abbreviated, time: .shortened))"
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
