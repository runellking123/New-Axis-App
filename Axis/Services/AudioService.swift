import AVFoundation
import Foundation

final class AudioService: @unchecked Sendable {
    static let shared = AudioService()

    static let availableSounds: [String] = [
        "rain", "coffee_shop", "fireplace", "ocean",
        "birds", "thunder", "piano", "white_noise"
    ]

    static func iconFor(_ sound: String) -> String {
        switch sound {
        case "rain": return "cloud.rain.fill"
        case "coffee_shop": return "cup.and.saucer.fill"
        case "fireplace": return "flame.fill"
        case "ocean": return "water.waves"
        case "birds": return "bird.fill"
        case "thunder": return "cloud.bolt.fill"
        case "piano": return "pianokeys"
        case "white_noise": return "waveform"
        default: return "speaker.wave.2.fill"
        }
    }

    static func labelFor(_ sound: String) -> String {
        sound.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var engine: AVAudioEngine?
    private var playerNodes: [String: AVAudioPlayerNode] = [:]
    private var audioFiles: [String: AVAudioFile] = [:]
    private var isRunning = false

    private init() {}

    func startEngine() {
        guard !isRunning else { return }
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioService] Failed to configure audio session: \(error)")
        }
        #endif

        engine = AVAudioEngine()
        isRunning = true
    }

    func playSound(_ name: String, volume: Float) {
        guard let engine = engine else {
            startEngine()
            playSound(name, volume: volume)
            return
        }

        // If already playing, just update volume
        if let node = playerNodes[name] {
            node.volume = volume
            return
        }

        // Try to load audio file from bundle
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3")
                ?? Bundle.main.url(forResource: name, withExtension: "wav")
                ?? Bundle.main.url(forResource: name, withExtension: "m4a") else {
            // Generate tone as fallback for missing audio files
            playGeneratedTone(name: name, volume: volume)
            return
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)

            if !engine.isRunning {
                try engine.start()
            }

            player.volume = volume
            player.scheduleFile(file, at: nil, completionHandler: nil)
            // Loop by scheduling repeatedly
            scheduleLoop(player: player, file: file)
            player.play()

            playerNodes[name] = player
            audioFiles[name] = file
        } catch {
            print("[AudioService] Error playing \(name): \(error)")
        }
    }

    private func scheduleLoop(player: AVAudioPlayerNode, file: AVAudioFile) {
        player.scheduleFile(file, at: nil) { [weak self] in
            DispatchQueue.main.async {
                if player.isPlaying {
                    self?.scheduleLoop(player: player, file: file)
                }
            }
        }
    }

    private func playGeneratedTone(name: String, volume: Float) {
        // For sounds without bundled files, create a simple placeholder node
        // In production, add actual audio files to the bundle
        let node = AVAudioPlayerNode()
        node.volume = volume
        playerNodes[name] = node
    }

    func stopSound(_ name: String) {
        guard let node = playerNodes[name] else { return }
        node.stop()
        engine?.detach(node)
        playerNodes.removeValue(forKey: name)
        audioFiles.removeValue(forKey: name)
    }

    func setVolume(_ name: String, volume: Float) {
        if volume <= 0 {
            stopSound(name)
        } else if let node = playerNodes[name] {
            node.volume = volume
        } else {
            playSound(name, volume: volume)
        }
    }

    func stopAll() {
        for (name, _) in playerNodes {
            stopSound(name)
        }
        engine?.stop()
        isRunning = false
    }

    var activeSounds: [String: Float] {
        var result: [String: Float] = [:]
        for (name, node) in playerNodes {
            result[name] = node.volume
        }
        return result
    }
}
