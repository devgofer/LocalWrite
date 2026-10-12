import Foundation

/// The lifecycle used by the microphone adapter. Time is monotonic and injected
/// so silence, cancellation and late recognition callbacks can be tested.
struct SpeechSession {
    enum Action: Equatable {
        case endAudio
        /// The recognizer closed its segment while the speaker is still talking:
        /// keep the text and start a new recognition request.
        case restart
        case finished(String)
        case failed(String)
    }

    private(set) var id: UUID?
    /// Everything heard so far, across recognizer segments.
    var transcript: String { Self.join(committed, current) }
    private var committed = ""
    private var current = ""
    private var restarts = 0
    private var startedAt: TimeInterval = 0
    private var lastSpeechAt: TimeInterval?
    private var finishingAt: TimeInterval?
    private var maxDuration: TimeInterval = 60
    private var stopsOnSilence = true

    /// With `stopsOnSilence` false, only `finish` or `maxDuration` ends the recording:
    /// the speaker decides when they are done.
    mutating func begin(at time: TimeInterval, maxDuration: TimeInterval = 60, stopsOnSilence: Bool = true) -> UUID {
        let id = UUID()
        self.id = id
        committed = ""; current = ""; restarts = 0
        startedAt = time
        lastSpeechAt = nil
        finishingAt = nil
        self.maxDuration = maxDuration
        self.stopsOnSilence = stopsOnSilence
        return id
    }

    mutating func cancel() { id = nil }

    mutating func audio(id: UUID, speechLike: Bool, at time: TimeInterval) {
        guard self.id == id, finishingAt == nil else { return }
        if speechLike { lastSpeechAt = time }
    }

    mutating func receive(id: UUID, text: String?, final: Bool, error: String?) -> Action? {
        guard self.id == id else { return nil }
        if let text, !text.isEmpty {
            // On-device recognition can start over after a pause; keep what came before.
            if Self.isReset(from: current, to: text) { committed = Self.join(committed, current) }
            current = text
        }
        guard final || error != nil else { return nil }
        if !stopsOnSilence, finishingAt == nil, restarts < 30 {
            restarts += 1
            committed = Self.join(committed, current); current = ""
            return .restart
        }
        self.id = nil
        if let error, stopsOnSilence || transcript.isEmpty { return .failed(error) }
        return outcome()
    }

    mutating func finish(at time: TimeInterval) -> Action? {
        guard id != nil, finishingAt == nil else { return nil }
        finishingAt = time
        return .endAudio
    }

    mutating func tick(at time: TimeInterval) -> Action? {
        guard id != nil else { return nil }
        if let finishingAt {
            guard time - finishingAt >= 3 else { return nil }
            id = nil
            return outcome()
        }
        if time - startedAt >= maxDuration && !stopsOnSilence {
            finishingAt = time
            return .endAudio
        }
        guard stopsOnSilence else { return nil }
        if lastSpeechAt == nil, transcript.isEmpty, time - startedAt >= 10 {
            id = nil
            return .failed("No speech detected. Please try again.")
        }
        if time - startedAt >= maxDuration || lastSpeechAt.map({ time - $0 >= 1.25 }) == true {
            finishingAt = time
            return .endAudio
        }
        return nil
    }

    static func isReset(from previous: String, to next: String) -> Bool {
        guard !previous.isEmpty, next.count * 2 < previous.count else { return false }
        return !previous.hasPrefix(String(next.prefix(3)))
    }

    /// Chinese joins directly; two Latin words get a space.
    static func join(_ first: String, _ second: String) -> String {
        let a = first.trimmingCharacters(in: .whitespaces), b = second.trimmingCharacters(in: .whitespaces)
        guard !a.isEmpty else { return b }
        guard !b.isEmpty else { return a }
        if let last = a.unicodeScalars.last, let next = b.unicodeScalars.first, last.isASCII, next.isASCII { return a + " " + b }
        return a + b
    }

    private func outcome() -> Action {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .failed("No speech detected. Please try again.") : .finished(text)
    }
}
