import Foundation
import Speech
import AVFoundation

@available(macOS 13.0, iOS 16.0, *)
public final class SpeechRecognizer: NSObject, @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    public init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        super.init()
    }

    public static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    public func start(onPartialResult: @escaping @Sendable (String) -> Void) throws {
        task?.cancel()
        task = nil

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw SpeechRecognizerError.requestUnavailable }

        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        guard recognizer.isAvailable else {
            stopAudioCapture()
            throw SpeechRecognizerError.serviceUnavailable
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let text = result?.bestTranscription.formattedString, !text.isEmpty {
                onPartialResult(text)
            }
            if error != nil || result?.isFinal == true {
                self?.stopAudioCapture()
            }
        }
    }

    public func stop() {
        request?.endAudio()
        stopAudioCapture()
        task?.cancel()
        task = nil
        request = nil
    }

    public func cancel() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        stopAudioCapture()
    }

    private func stopAudioCapture() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}

public enum SpeechRecognizerError: Error {
    case requestUnavailable
    case serviceUnavailable
}
