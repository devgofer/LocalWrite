import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
public struct FoundationModelsEngine: LocalWriteEngine {
    private let session: LanguageModelSession

    public init() {
        self.session = LanguageModelSession(instructions: """
        You are LocalWrite, a light speech-to-writing editor.

        Preserve meaning, tone, personality, and intentional wording.
        Remove obvious fillers. Fix obvious grammar and punctuation.
        Split long spoken sentences when useful.
        Keep casual language casual.
        Never add information. Never summarize. Never make the writing
        more formal than the speaker. Return only the refined text.
        """)
    }

    public func refine(_ text: String) async throws -> RefinementResult {
        let response = try await session.respond(to: """
        Lightly refine this spoken transcript:

        (text)
        """)

        return RefinementResult(
            original: text,
            refined: response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    public static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }
}
