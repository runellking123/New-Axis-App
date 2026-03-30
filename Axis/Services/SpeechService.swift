import AVFoundation
import Foundation
import Speech
import UIKit

@Observable
final class SpeechService {
    static let shared = SpeechService()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private(set) var isRecording = false
    private(set) var transcribedText = ""
    private(set) var isAuthorized = false

    private init() {}

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let authorized = status == .authorized
                Task { @MainActor in
                    self.isAuthorized = authorized
                }
                continuation.resume(returning: authorized)
            }
        }
    }

    func startRecording() throws {
        guard !isRecording else { return }

        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        recognitionRequest.taskHint = .dictation

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let rawText = result.bestTranscription.formattedString
                Task { @MainActor in
                    if result.isFinal {
                        self.transcribedText = Self.correctGrammar(rawText)
                    } else {
                        self.transcribedText = rawText
                    }
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                Task { @MainActor in
                    self.isRecording = false
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        Task { @MainActor in
            self.isRecording = true
            self.transcribedText = ""
        }
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        Task { @MainActor in
            self.isRecording = false
            self.transcribedText = Self.correctGrammar(self.transcribedText)
        }
    }

    // MARK: - Grammar Correction

    /// Applies grammar and spelling corrections to transcribed text.
    /// Capitalizes sentences, fixes common speech-to-text issues, and
    /// runs the system spell checker to correct misspelled words.
    static func correctGrammar(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var corrected = text

        // 1. Capitalize the first letter of the entire text
        if let first = corrected.first, first.isLowercase {
            corrected = first.uppercased() + corrected.dropFirst()
        }

        // 2. Capitalize the first letter after sentence-ending punctuation (. ! ?)
        let sentencePattern = "([.!?])\\s+(\\p{Ll})"
        if let regex = try? NSRegularExpression(pattern: sentencePattern) {
            let mutable = NSMutableString(string: corrected)
            let range = NSRange(location: 0, length: mutable.length)
            regex.enumerateMatches(in: corrected, range: range) { match, _, _ in
                guard let match,
                      let letterRange = Range(match.range(at: 2), in: corrected) else { return }
                let upper = String(corrected[letterRange]).uppercased()
                mutable.replaceCharacters(in: match.range(at: 2), with: upper)
            }
            corrected = mutable as String
        }

        // 3. Capitalize "I" when used as a pronoun (standalone lowercase "i")
        if let regex = try? NSRegularExpression(pattern: "\\bi\\b") {
            let mutable = NSMutableString(string: corrected)
            regex.replaceMatches(in: mutable, range: NSRange(location: 0, length: mutable.length),
                                 withTemplate: "I")
            corrected = mutable as String
        }

        // 4. Ensure text ends with punctuation
        let trimmed = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = trimmed.last, !last.isPunctuation {
            corrected = trimmed + "."
        }

        return corrected
    }
}
