import Foundation
import Speech
import AVFoundation

@available(macOS 13.0, iOS 16.0, *)
public final class SpeechRecognizer: NSObject, @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private let stateQueue = DispatchQueue(label: "com.devgofer.LocalWrite.speech-state")

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceWorkItem: DispatchWorkItem?
    private var latestTranscript = ""
    private var completion: (@Sendable (String) -> Void)?
    private let silenceTimeout: TimeInterval = 1.25
    private let minimumSpeechDuration: TimeInterval = 0.25
    private var speechStartedAt: Date?

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

    public func start(
        onPartialResult: @escaping @Sendable (String) -> Void,
        onFinished: @escaping @Sendable (String) -> Void
    ) throws {
        cancel()

        guard recognizer.isAvailable else {
            throw SpeechRecognizerError.serviceUnavailable
        }

        guard recognizer.supportsOnDeviceRecognition else {
            throw SpeechRecognizerError.onDeviceRecognitionUnavailable
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        latestTranscript = ""
        completion = onFinished
        speechStartedAt = nil
        request = recognitionRequest

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            request = nil
            completion = nil
            throw SpeechRecognizerError.audioInputUnavailable
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            self?.processAudioLevel(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            stopAudioCapture()
            request = nil
            completion = nil
            throw error
        }

        task = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            self.stateQueue.async {
                if let text = result?.bestTranscription.formattedString, !text.isEmpty {
                    self.latestTranscript = text
                    onPartialResult(text)

                    if result?.isFinal == true {
                        self.complete(with: text)
                    }
                } else if error != nil, !self.latestTranscript.isEmpty {
                    self.complete(with: self.latestTranscript)
                }
            }
        }
    }

    public func cancel() {
        stateQueue.sync {
            silenceWorkItem?.cancel()
            silenceWorkItem = nil
            task?.cancel()
            task = nil
            request?.endAudio()
            request = nil
            completion = nil
            latestTranscript = ""
            speechStartedAt = nil
            stopAudioCapture()
        }
    }

    private func processAudioLevel(_ buffer: AVAudioPCMBuffer) {
        stateQueue.async { [weak self] in
            guard let self else { return }

            guard let channelData = buffer.floatChannelData,
                  buffer.frameLength > 0,
                  buffer.format.channelCount > 0 else {
                return
            }

            let frameCount = Int(buffer.frameLength)
            let channel = channelData[0]

            var sumSquares: Float = 0
            for index in 0..<frameCount {
                let sample = channel[index]
                sumSquares += sample * sample
            }

            let rms = sqrt(sumSquares / Float(frameCount))
            let decibels = 20 * log10(max(rms, 0.000_01))
            let isSpeechLike = decibels > -42

            if isSpeechLike {
                self.speechStartedAt = self.speechStartedAt ?? Date()
                self.silenceWorkItem?.cancel()
                self.silenceWorkItem = nil
                return
            }

            guard !self.latestTranscript.isEmpty,
                  let startedAt = self.speechStartedAt,
                  Date().timeIntervalSince(startedAt) >= self.minimumSpeechDuration,
                  self.silenceWorkItem == nil else {
                return
            }

            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.stateQueue.async {
                    guard self.silenceWorkItem != nil else { return }
                    self.request?.endAudio()
                    self.complete(with: self.latestTranscript)
                }
            }

            self.silenceWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + self.silenceTimeout, execute: item)
        }
    }

    private func complete(with text: String) {
        let callback = completion
        completion = nil

        silenceWorkItem?.cancel()
        silenceWorkItem = nil
        stopAudioCapture()
        task?.cancel()
        task = nil
        request = nil
        speechStartedAt = nil

        callback?(text)
    }

    private func stopAudioCapture() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}

public enum SpeechRecognizerError: LocalizedError {
    case requestUnavailable
    case serviceUnavailable
    case onDeviceRecognitionUnavailable
    case audioInputUnavailable

    public var errorDescription: String? {
        switch self {
        case .requestUnavailable:
            return "Speech recognition request is unavailable."
        case .serviceUnavailable:
            return "Speech recognition service is unavailable."
        case .onDeviceRecognitionUnavailable:
            return "On-device speech recognition is unavailable for this language or device."
        case .audioInputUnavailable:
            return "No usable microphone input is available."
        }
    }
}
