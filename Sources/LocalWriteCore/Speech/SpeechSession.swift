import Foundation

/// The lifecycle used by the microphone adapter. Time is monotonic and injected
/// so silence, cancellation and late recognition callbacks can be tested.
struct SpeechSession {
    enum Action: Equatable {
        case endAudio
        case finished(String)
        case failed(String)
    }

    private(set) var id: UUID?
    private(set) var transcript = ""
    private var startedAt: TimeInterval = 0
    private var lastSpeechAt: TimeInterval?
    private var finishingAt: TimeInterval?

    mutating func begin(at time: TimeInterval) -> UUID {
        let id = UUID()
        self.id = id
        transcript = ""
        startedAt = time
        lastSpeechAt = nil
        finishingAt = nil
        return id
    }

    mutating func cancel() { id = nil }

    mutating func audio(id: UUID, speechLike: Bool, at time: TimeInterval) {
        guard self.id == id, finishingAt == nil else { return }
        if speechLike { lastSpeechAt = time }
    }

    mutating func receive(id: UUID, text: String?, final: Bool, error: String?) -> Action? {
        guard self.id == id else { return nil }
        if let text, !text.isEmpty { transcript = text }
        if final {
            self.id = nil
            return outcome()
        }
        if let error {
            self.id = nil
            return .failed(error)
        }
        return nil
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
        if lastSpeechAt == nil, transcript.isEmpty, time - startedAt >= 10 {
            id = nil
            return .failed("No speech detected. Please try again.")
        }
        if time - startedAt >= 60 || lastSpeechAt.map({ time - $0 >= 1.25 }) == true {
            finishingAt = time
            return .endAudio
        }
        return nil
    }

    private func outcome() -> Action {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .failed("No speech detected. Please try again.") : .finished(text)
    }
}
