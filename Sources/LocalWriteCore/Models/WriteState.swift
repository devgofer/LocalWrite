import Foundation

public enum WriteState: Equatable, Sendable {
    case idle
    case listening
    case refining
    case inserting
    case error(String)
}
