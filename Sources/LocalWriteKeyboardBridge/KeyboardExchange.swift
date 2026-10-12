import Foundation

/// What the keyboard asks the app to do with the transcript.
public enum DictationMode: String, Codable, Sendable, CaseIterable {
    case clean, translate
}

/// Target languages offered for translation. `englishName` goes to the model prompt.
public struct TranslationLanguage: Hashable, Sendable, Identifiable {
    public let code: String
    public let displayName: String
    public let englishName: String
    public var id: String { code }

    public static let all: [Self] = [
        .init(code: "en", displayName: "English", englishName: "English"),
        .init(code: "zh-Hant", displayName: "繁體中文", englishName: "Traditional Chinese (Taiwan)"),
        .init(code: "ja", displayName: "日本語", englishName: "Japanese"),
        .init(code: "ko", displayName: "한국어", englishName: "Korean"),
        .init(code: "es", displayName: "Español", englishName: "Spanish"),
        .init(code: "fr", displayName: "Français", englishName: "French"),
        .init(code: "de", displayName: "Deutsch", englishName: "German")
    ]

    public static func named(_ code: String) -> Self { all.first { $0.code == code } ?? all[0] }
}

/// Published by the app while its microphone session is warm. The keyboard reads it
/// to decide whether a tap can dictate in place or must open the app first.
public struct VoiceState: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable { case idle, recording, processing, done, failed, ended }

    /// The app refreshes `updatedAt` this often while warm.
    public static let heartbeatInterval: TimeInterval = 2
    /// Older than this, the app is assumed suspended or killed.
    public static let heartbeatTimeout: TimeInterval = 8

    public var sessionID: UUID
    public var phase: Phase
    public var requestID: UUID?
    public var text: String
    /// True when the model failed and `text` is the unedited transcript.
    public var usedRawFallback: Bool
    /// Microphone loudness, 0 to 1, while recording, for the keyboard's waveform.
    public var level: Float
    public var message: String
    public var expiresAt: Date
    public var updatedAt: Date

    public init(sessionID: UUID, phase: Phase, requestID: UUID? = nil, text: String = "",
                usedRawFallback: Bool = false, level: Float = 0, message: String = "",
                expiresAt: Date, updatedAt: Date = .now) {
        self.sessionID = sessionID; self.phase = phase; self.requestID = requestID
        self.text = text; self.usedRawFallback = usedRawFallback; self.level = level; self.message = message
        self.expiresAt = expiresAt; self.updatedAt = updatedAt
    }

    public func isWarm(at now: Date = .now) -> Bool {
        let age = now.timeIntervalSince(updatedAt)
        return phase != .ended && now < expiresAt && age > -2 && age < Self.heartbeatTimeout
    }
}

public struct KeyboardCommand: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case start, finish, cancel }
    public let id: UUID
    public let requestID: UUID
    public let kind: Kind
    public let mode: DictationMode
    public let targetLanguage: String
    /// The kind of field being typed in: email, chat, document or general.
    public let style: String
    public let createdAt: Date

    public init(requestID: UUID, kind: Kind, mode: DictationMode = .clean,
                targetLanguage: String = "en", style: String = "general", createdAt: Date = .now) {
        id = UUID(); self.requestID = requestID; self.kind = kind
        self.mode = mode; self.targetLanguage = targetLanguage; self.style = style; self.createdAt = createdAt
    }

    public func isFresh(at now: Date = .now) -> Bool {
        let age = now.timeIntervalSince(createdAt)
        return age > -2 && age < 10
    }
}

/// A keyboard tap writes this ticket before opening the app. A URL alone cannot
/// turn on the microphone: the app must find the matching ticket in the App Group.
public struct KeyboardLaunchRequest: Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    /// The app the keyboard was typing in, when iOS reveals it, so LocalWrite can switch back.
    public let hostBundleID: String?
    public init(id: UUID = UUID(), createdAt: Date = .now, hostBundleID: String? = nil) {
        self.id = id; self.createdAt = createdAt; self.hostBundleID = hostBundleID
    }
    public var url: URL { URL(string: "localwrite://session/\(id.uuidString)")! }
    public func matches(_ url: URL, at now: Date = .now) -> Bool {
        url.scheme == "localwrite" && url.host == "session" &&
        url.path == "/\(id.uuidString)" && url.query == nil && url.fragment == nil &&
        now.timeIntervalSince(createdAt) > -2 && now.timeIntervalSince(createdAt) < 30
    }
}

/// Atomic files in the App Group, each with one writer: the app writes state,
/// the keyboard writes commands and launch tickets. Darwin notifications say when to read.
public struct KeyboardExchange: Sendable {
    public static let appGroup = "group.com.devgofer.LocalWrite"
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    public static func shared() -> Self? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            .map { Self(directory: $0.appendingPathComponent("Library/Caches/LocalWrite", isDirectory: true)) }
    }

    public func write(_ value: VoiceState) throws { try write(value, name: "voice-state.json") }
    public func state() -> VoiceState? { read("voice-state.json") }

    public func write(_ value: KeyboardCommand) throws { try write(value, name: "voice-command.json") }
    public func command() -> KeyboardCommand? { read("voice-command.json") }

    public func write(_ value: KeyboardLaunchRequest) throws { try write(value, name: "voice-launch.json") }
    public func launchRequest() -> KeyboardLaunchRequest? { read("voice-launch.json") }
    public func clearLaunchRequest() throws { try remove("voice-launch.json") }

    /// Appends a line to a small log both processes share, for on-device debugging.
    public func diagnose(_ line: String) {
        let url = directory.appendingPathComponent("diagnostics.log")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let entry = Data("\(ISO8601DateFormatter().string(from: .now)) \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            if (try? handle.seekToEnd()) ?? 0 > 64_000 { try? handle.truncate(atOffset: 0) }
            try? handle.write(contentsOf: entry)
        } else {
            try? entry.write(to: url)
        }
    }

    private func write<T: Encodable>(_ value: T, name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: directory.appendingPathComponent(name), options: .atomic)
    }
    private func read<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    private func remove(_ name: String) throws {
        let url = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

/// Preferences shared by the app and the keyboard.
public struct SharedSettings: @unchecked Sendable {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults) { self.defaults = defaults }
    public static func shared() -> Self { Self(defaults: UserDefaults(suiteName: KeyboardExchange.appGroup) ?? .standard) }


    public var mode: DictationMode {
        get { defaults.string(forKey: "mode").flatMap(DictationMode.init(rawValue:)) ?? .clean }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "mode") }
    }
    public var targetLanguage: String {
        get { defaults.string(forKey: "targetLanguage") ?? "en" }
        nonmutating set { defaults.set(newValue, forKey: "targetLanguage") }
    }
}

/// The keyboard inserts only the result it asked for, into the same field, once.
public struct KeyboardDelivery: Sendable {
    public private(set) var requestID: UUID?
    private var documentID: UUID?
    public init() {}

    public mutating func begin(documentID: UUID) -> UUID {
        let id = UUID(); requestID = id; self.documentID = documentID
        return id
    }
    public func belongsTo(documentID: UUID) -> Bool { self.documentID == documentID }
    public mutating func cancel() { requestID = nil; documentID = nil }

    public mutating func consume(_ state: VoiceState, documentID: UUID) -> String? {
        guard let requestID, state.requestID == requestID, state.phase == .done,
              self.documentID == documentID, !state.text.isEmpty else { return nil }
        cancel()
        return state.text
    }
}
