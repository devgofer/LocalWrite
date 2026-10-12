import Foundation

public protocol LocalWriteEngine: Sendable {
    func refine(_ text: String) async throws -> RefinementResult
    /// Edits for the destination app's conventions. Defaults to ignoring the context.
    func refine(_ text: String, context: WritingContext) async throws -> RefinementResult
}

public extension LocalWriteEngine {
    func refine(_ text: String, context: WritingContext) async throws -> RefinementResult { try await refine(text) }
}
