import Foundation

public struct RefinementResult: Sendable, Equatable {
    public let original: String
    public let refined: String

    public init(original: String, refined: String) {
        self.original = original
        self.refined = refined
    }

    public var changed: Bool {
        original != refined
    }
}
