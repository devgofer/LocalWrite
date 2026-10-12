import Foundation

/// Where the dictated text is going, so the edit can match that app's conventions
/// (Typeless's per-app tone): "hi anna" becomes "Hi Anna," in Gmail and "Hi, Anna" in WhatsApp.
public struct WritingContext: Sendable, Equatable {
    public enum Style: String, Sendable, CaseIterable {
        case email, chat, document, general
    }

    public var appName: String?
    public var style: Style

    public init(appName: String? = nil, style: Style = .general) {
        self.appName = appName; self.style = style
    }

    public static let general = Self()

    /// Classifies by app bundle ID, plus the window title for browsers (Gmail in Chrome).
    public static func classify(bundleID: String?, appName: String?, windowTitle: String? = nil) -> Self {
        let id = bundleID?.lowercased() ?? ""
        let title = windowTitle?.lowercased() ?? ""
        let style: Style
        if emailApps.contains(where: id.hasPrefix) || ["gmail", "outlook", "yahoo mail", "proton mail"].contains(where: title.contains) {
            style = .email
        } else if chatApps.contains(where: id.hasPrefix)
                    || ["whatsapp", "messenger", "slack", "discord", "telegram", "line", "teams"].contains(where: title.contains) {
            style = .chat
        } else if documentApps.contains(where: id.hasPrefix)
                    || ["google docs", "notion", "confluence"].contains(where: title.contains) {
            style = .document
        } else {
            style = .general
        }
        let titledApp = browsers.contains(where: id.hasPrefix) && !title.isEmpty ? windowTitle : nil
        return Self(appName: [appName, titledApp].compactMap { $0 }.joined(separator: " — "), style: style)
    }

    private static let emailApps = ["com.apple.mail", "com.microsoft.outlook", "com.readdle.smartemail", "com.google.gmail",
                                    "com.superhuman", "it.bloop.airmail", "com.apple.mobilemail"]
    private static let chatApps = ["net.whatsapp", "com.apple.mobilesms", "com.apple.ichat", "com.tinyspeck.slackmacgap",
                                   "jp.naver.line", "ru.keepcoder.telegram", "org.telegram", "com.hnc.discord",
                                   "com.tencent.xinwechat", "com.facebook.archon", "com.microsoft.teams",
                                   "com.facebook.messenger", "desktop.whatsapp"]
    private static let documentApps = ["com.apple.iwork.pages", "com.microsoft.word", "com.apple.notes", "com.apple.mobilenotes",
                                       "notion.id", "md.obsidian", "com.apple.textedit", "com.ulyssesapp", "net.shinyfrog.bear"]
    private static let browsers = ["com.google.chrome", "com.apple.safari", "company.thebrowser", "org.mozilla.firefox",
                                   "com.microsoft.edgemac", "com.brave.browser"]

    /// Greeting punctuation is a fixed convention, so it is applied deterministically
    /// after the model: "Hi Anna," on its own line in email, "Hi, Anna, ..." in chat.
    public func formatGreeting(_ text: String) -> String {
        guard style == .email || style == .chat,
              let match = text.firstMatch(of: #/^(?i)(hi|hey|hello|dear)[\s,]+([a-z][a-z'-]*)[\s,!.]*/#) else { return text }
        let greeting = String(match.1).prefix(1).uppercased() + String(match.1).dropFirst().lowercased()
        let name = String(match.2).prefix(1).uppercased() + String(match.2).dropFirst()
        var rest = String(text[match.range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rest.isEmpty else { return style == .email ? "\(greeting) \(name)," : "\(greeting), \(name)!" }
        if style == .email {
            rest = rest.prefix(1).uppercased() + rest.dropFirst()
            return "\(greeting) \(name),\n\n\(rest)"
        }
        if let first = rest.first, first.isUppercase, rest.dropFirst().first?.isLowercase == true, !rest.hasPrefix("I ") {
            rest = first.lowercased() + rest.dropFirst()
        }
        return "\(greeting), \(name), \(rest)"
    }

    /// One line for the prompt.
    var promptLine: String {
        let app = appName.flatMap { $0.isEmpty ? nil : "\"\($0)\"" } ?? "an unknown app"
        return switch style {
        case .email: "The text goes into \(app), an email. Use email conventions."
        case .chat: "The text goes into \(app), a chat. Use chat conventions."
        case .document: "The text goes into \(app), a document or note. Use document conventions."
        case .general: "The text goes into \(app). Keep it neutral."
        }
    }
}
