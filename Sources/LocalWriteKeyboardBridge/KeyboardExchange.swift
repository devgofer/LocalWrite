import Foundation

public struct KeyboardSnapshot: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable { case starting, ready, recording, refining, completed, failed, stopped }
    public var sessionID: UUID
    public var requestID: UUID?
    public var phase: Phase
    public var text: String
    public var message: String
    public var updatedAt: Date
    public init(sessionID: UUID, requestID: UUID? = nil, phase: Phase, text: String = "", message: String = "", updatedAt: Date = .now) {
        self.sessionID = sessionID; self.requestID = requestID; self.phase = phase
        self.text = text; self.message = message; self.updatedAt = updatedAt
    }
    public func isLive(at time: Date = .now) -> Bool {
        let age = time.timeIntervalSince(updatedAt)
        // Recording needs a live heartbeat. A completed result must survive iOS
        // suspending the app after its background processing time ends.
        let lifetime: TimeInterval = switch phase {
        case .starting: 90
        case .completed, .failed: 120
        default: 4
        }
        return phase != .stopped && age >= -2 && age < lifetime
    }
}

public struct KeyboardCommand: Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case start, finish, cancel }
    public let id: UUID
    public let sessionID: UUID
    public let requestID: UUID
    public let kind: Kind
    public let createdAt: Date
    public init(sessionID: UUID, requestID: UUID, kind: Kind, createdAt: Date = .now) {
        id = UUID(); self.sessionID = sessionID; self.requestID = requestID
        self.kind = kind; self.createdAt = createdAt
    }
    public func isValid(for session: UUID, at now: Date = .now) -> Bool {
        sessionID == session && now.timeIntervalSince(createdAt) >= -2 && now.timeIntervalSince(createdAt) < 5
    }
}

/// Separate atomic files, each with exactly one writer: the helper writes status;
/// the visible keyboard writes commands. No transcript goes through the clipboard.
public struct KeyboardExchange: Sendable {
    public static let appGroup = "group.com.devgofer.LocalWrite"
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    public static func shared() -> Self? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            .map { Self(directory: $0.appendingPathComponent("Library/Caches/LocalWrite", isDirectory: true)) }
    }
    public func write(_ value: KeyboardSnapshot) throws { try write(value, name: "voice-status.json") }
    public func write(_ value: KeyboardPendingRequest) throws { try write(value, name: "voice-pending.json") }
    public func pendingRequest() -> KeyboardPendingRequest? { read("voice-pending.json") }
    public func clearPendingRequest() throws {
        let url = directory.appendingPathComponent("voice-pending.json")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    public func write(_ value: KeyboardLaunchRequest) throws { try write(value, name: "voice-launch.json") }
    public func launchRequest() -> KeyboardLaunchRequest? { read("voice-launch.json") }
    public func clearLaunchRequest() throws {
        let url = directory.appendingPathComponent("voice-launch.json")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    public func write(_ value: KeyboardCommand) throws { try write(value, name: "voice-command.json") }
    public func snapshot() -> KeyboardSnapshot? { read("voice-status.json") }
    public func command() -> KeyboardCommand? { read("voice-command.json") }
    private func write<T: Encodable>(_ value: T, name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: directory.appendingPathComponent(name), options: .atomic)
    }
    private func read<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

/// The extension inserts only the result requested by this visible keyboard,
/// in the same document, once. A newly opened keyboard never pastes old results.
public struct KeyboardDelivery: Sendable {
    public private(set) var requestID: UUID?
    public private(set) var sessionID: UUID?
    private var documentID: UUID?
    public init() {}
    public mutating func begin(sessionID: UUID, documentID: UUID) -> UUID {
        let id = UUID(); requestID = id; self.sessionID = sessionID; self.documentID = documentID
        return id
    }
    public mutating func resume(_ pending: KeyboardPendingRequest, documentID: UUID, at now: Date = .now) -> Bool {
        guard pending.documentID == documentID,
              now.timeIntervalSince(pending.ticket.createdAt) >= -2,
              now.timeIntervalSince(pending.ticket.createdAt) < 120 else { return false }
        requestID = pending.ticket.requestID; sessionID = pending.ticket.sessionID
        self.documentID = documentID
        return true
    }
    public func belongsTo(documentID: UUID) -> Bool { self.documentID == documentID }
    public mutating func cancel() { requestID = nil; sessionID = nil; documentID = nil }
    public mutating func consume(_ snapshot: KeyboardSnapshot, documentID: UUID, at now: Date = .now) -> String? {
        guard snapshot.isLive(at: now), snapshot.phase == .completed,
              snapshot.sessionID == sessionID, snapshot.requestID == requestID,
              self.documentID == documentID, !snapshot.text.isEmpty else { return nil }
        cancel()
        return snapshot.text
    }
}

/// A keyboard tap creates a short-lived ticket before opening the app. A URL alone
/// cannot start recording: the app must match the ticket in its private App Group.
public struct KeyboardLaunchRequest: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let requestID: UUID
    public let createdAt: Date
    public init(sessionID: UUID, requestID: UUID, createdAt: Date = .now) {
        self.sessionID = sessionID; self.requestID = requestID; self.createdAt = createdAt
    }
    public var url: URL {
        URL(string: "localwrite://dictate/\(requestID.uuidString)")!
    }
    public func matches(_ url: URL, at now: Date = .now) -> Bool {
        url.scheme == "localwrite" && url.host == "dictate" &&
        url.path == "/\(requestID.uuidString)" && url.query == nil && url.fragment == nil &&
        now.timeIntervalSince(createdAt) >= -2 && now.timeIntervalSince(createdAt) < 30
    }
}

/// Saved only during a dictation so the keyboard can recover after iOS recreates
/// its controller during the app switch. Context is cleared with the request.
public struct KeyboardPendingRequest: Codable, Sendable {
    public let ticket: KeyboardLaunchRequest
    public let documentID: UUID
    public let before: String?
    public let after: String?
    public init(ticket: KeyboardLaunchRequest, documentID: UUID, before: String?, after: String?) {
        self.ticket = ticket; self.documentID = documentID; self.before = before; self.after = after
    }
}
