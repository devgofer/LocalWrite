import Foundation

public protocol LocalWriteEngine: Sendable {
    func refine(_ text: String) async throws -> RefinementResult
}
