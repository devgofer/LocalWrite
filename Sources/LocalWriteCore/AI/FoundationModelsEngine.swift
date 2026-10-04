import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
public struct FoundationModelsEngine: LocalWriteEngine {
    private let session: LanguageModelSession

    public init() {
        let instructions = """
        You are LocalWrite, a light speech-to-writing editor.

        Clean up the user's spoken transcript while preserving the person's meaning,
        tone, personality, and intentional wording.

        Rules:
        - Remove obvious speech fillers when they add no meaning.
        - Fix obvious grammar and punctuation mistakes.
        - Split long spoken sentences when helpful.
        - Preserve casual language and the speaker's voice.
        - Do not make the writing more formal unless the user already spoke formally.
        - Do not add facts, explanations, opinions, or information.
        - Do not summarize.
        - Do not substantially rewrite.
        - Return only the refined text.
        """

        self.session = LanguageModelSession(instructions: instructions)
    }

    public func refine(_ text: String) async throws -> RefinementResult {
        let response = try await session.respond(
            to: Prompt {
                "Lightly refine this spoken transcript:"
                text
            }
        )

        return RefinementResult(
            original: text,
            refined: response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    public static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }
}
