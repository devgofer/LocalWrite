import Foundation
import Speech
import AVFoundation

@MainActor
public final class SpeechRecognizer {
    private var recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var audioRequest: AudioRequest?
    private var externalFeed: SpeechAudioFeed?
    private var task: SFSpeechRecognitionTask?
    private var timer: Task<Void, Never>?
    private var session = SpeechSession()
    private var tapInstalled = false
    private var partial: (@MainActor (String) -> Void)?
    private var completion: (@MainActor (String) -> Void)?
    private var failure: (@MainActor (String) -> Void)?
    /// Microphone loudness from 0 to 1, about 40 times a second, for a waveform.
    public var onLevel: (@MainActor (Float) -> Void)?

    public var currentLocale: Locale {
        get { recognizer?.locale ?? .current }
        set { recognizer = SFSpeechRecognizer(locale: newValue) }
    }

    public init(locale: Locale = Locale(identifier: "zh-TW")) {
        recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: .current)
    }

    isolated deinit { cancel() }

    nonisolated public static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    nonisolated public static func requestMicrophoneAuthorization() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    public func start(
        onPartialResult: @escaping @MainActor (String) -> Void,
        onFinished: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) throws {
        try start(externalAudioFeed: nil, onPartialResult: onPartialResult, onFinished: onFinished, onError: onError)
    }

    public func start(externalAudioFeed: SpeechAudioFeed?,
        onPartialResult: @escaping @MainActor (String) -> Void,
        onFinished: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) throws {
        cancel()
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognizerError.serviceUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw SpeechRecognizerError.onDeviceRecognitionUnavailable
        }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw SpeechRecognizerError.microphonePermissionRequired
        }

        // Like Typeless, the speaker decides when to stop; silence never ends a recording.
        let id = session.begin(at: ProcessInfo.processInfo.systemUptime, maxDuration: 300, stopsOnSilence: false)
        partial = onPartialResult
        completion = onFinished
        failure = onError
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.addsPunctuation = true
        let input = AudioRequest(request)
        audioRequest = input

        do {
            if let externalAudioFeed {
                externalFeed = externalAudioFeed
                externalAudioFeed.set(input)
            } else {
            let node = audioEngine.inputNode
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw SpeechRecognizerError.audioInputUnavailable
            }
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable [weak self] buffer, _ in
                input.append(buffer)
                // Read the callback-owned buffer here; only scalars cross actors.
                let decibels = Self.decibels(buffer)
                let speechLike = decibels > -42
                let level = Float(min(max((decibels + 55) / 45, 0), 1))  // same scale as level(_:)
                let time = ProcessInfo.processInfo.systemUptime
                Task { @MainActor [weak self] in
                    self?.session.audio(id: id, speechLike: speechLike, at: time)
                    self?.onLevel?(level)
                }
            }
            tapInstalled = true
            }
            task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal ?? false
                let message = error?.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.session.id == id else { return }
                    let action = self.session.receive(id: id, text: text, final: final, error: message)
                    if let text, !text.isEmpty { self.partial?(text) }
                    self.handle(action)
                }
            }
            if externalAudioFeed == nil {
                audioEngine.prepare()
                try audioEngine.start()
            }
            timer = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(100)) }
                    catch { return }
                    guard let self, self.session.id == id else { return }
                    self.handle(self.session.tick(at: ProcessInfo.processInfo.systemUptime))
                }
            }
        } catch {
            cancel()
            throw error
        }
    }

    public func finish() {
        handle(session.finish(at: ProcessInfo.processInfo.systemUptime))
    }

    public func cancel() {
        session.cancel()
        cleanup()
    }

    private func handle(_ action: SpeechSession.Action?) {
        guard let action else { return }
        switch action {
        case .endAudio:
            externalFeed?.set(nil)
            stopAudioCapture()
            audioRequest?.end()
            // Keep the recognition task alive until final or the bounded timeout.
        case .finished(let text):
            let callback = completion
            cleanup()
            callback?(text)
        case .failed(let message):
            let callback = failure
            cleanup()
            callback?(message)
        }
    }

    private func cleanup() {
        externalFeed?.set(nil)
        externalFeed = nil
        timer?.cancel()
        timer = nil
        stopAudioCapture()
        audioRequest?.end()
        audioRequest = nil
        task?.cancel()
        task = nil
        partial = nil
        completion = nil
        failure = nil
    }

    private func stopAudioCapture() {
        audioEngine.stop()
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    /// Loudness from 0 (silence) to 1 (loud speech).
    nonisolated public static func level(_ buffer: AVAudioPCMBuffer) -> Float {
        Float(min(max((decibels(buffer) + 55) / 45, 0), 1))
    }

    nonisolated private static func decibels(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return -100 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += channels[0][index] * channels[0][index] }
        let rms = sqrt(sum / Float(buffer.frameLength))
        return 20 * log10(max(rms, 0.000_01))
    }
}

/// The audio callback and main actor share only this locked request adapter.
/// All append/end accesses are serialized; audio buffers never leave the tap.
fileprivate final class AudioRequest: @unchecked Sendable {
    private let lock = NSLock()
    private let request: SFSpeechAudioBufferRecognitionRequest
    private var ended = false

    init(_ request: SFSpeechAudioBufferRecognitionRequest) { self.request = request }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        if !ended { request.append(buffer) }
    }

    func end() {
        lock.lock()
        defer { lock.unlock() }
        guard !ended else { return }
        ended = true
        request.endAudio()
    }
}

public enum SpeechRecognizerError: LocalizedError {
    case serviceUnavailable
    case onDeviceRecognitionUnavailable
    case audioInputUnavailable
    case microphonePermissionRequired

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable: "Speech recognition is unavailable for this language or device."
        case .onDeviceRecognitionUnavailable: "On-device speech recognition is unavailable for this language or device."
        case .audioInputUnavailable: "No usable microphone input is available."
        case .microphonePermissionRequired: "Microphone permission is required."
        }
    }
}


/// An already-running foreground-authorized audio source can feed a speech request.
/// The helper keeps its audio engine alive; buffers outside a dictation are discarded.
public final class SpeechAudioFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var request: AudioRequest?
    private let levelHandler: (@Sendable (Float) -> Void)?
    /// `onLevel` receives loudness from 0 to 1 on the audio queue for every buffer.
    public init(onLevel: (@Sendable (Float) -> Void)? = nil) { levelHandler = onLevel }
    /// Created outside actor isolation; AVAudioEngine invokes it on its audio queue.
    public func makeTapHandler() -> AVAudioNodeTapBlock {
        { @Sendable [self] buffer, _ in
            append(buffer)
            if let levelHandler { levelHandler(SpeechRecognizer.level(buffer)) }
        }
    }
    fileprivate func set(_ request: AudioRequest?) {
        lock.lock(); defer { lock.unlock() }
        self.request = request
    }
    public func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        request?.append(buffer)
    }
}
