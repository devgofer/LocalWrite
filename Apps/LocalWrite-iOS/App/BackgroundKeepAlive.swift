import AVFoundation

/// Plays silence so iOS keeps LocalWrite running in the background (audio background
/// mode) without the microphone on. Recording then starts only when the keyboard asks.
@MainActor
final class BackgroundKeepAlive {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var attached = false

    var running: Bool { engine.isRunning }

    func start() throws {
        guard !engine.isRunning else { return }
        let format = engine.outputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0,
              let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate)) else {
            throw KeepAliveError.outputUnavailable
        }
        silence.frameLength = silence.frameCapacity  // buffers are zero-filled
        if !attached {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            attached = true
        }
        engine.prepare()
        try engine.start()
        player.scheduleBuffer(silence, at: nil, options: .loops)
        player.play()
    }

    func stop() {
        player.stop()
        engine.stop()
    }
}

enum KeepAliveError: LocalizedError {
    case outputUnavailable
    var errorDescription: String? { "No audio output is available." }
}
