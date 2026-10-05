import Foundation

enum LocalWriteSettings {
    static let shortcutModifierKey = "shortcutModifier"
    static let shortcutKey = "shortcutKey"
    static let silenceTimeoutKey = "silenceTimeout"

    static let defaultShortcutModifier = "option"
    static let defaultShortcutKey = "Space"
    static let defaultSilenceTimeout = 1.25

    static var shortcutModifier: String {
        UserDefaults.standard.string(forKey: shortcutModifierKey) ?? defaultShortcutModifier
    }

    static var shortcutKey: String {
        UserDefaults.standard.string(forKey: shortcutKey) ?? defaultShortcutKey
    }

    static var silenceTimeout: Double {
        let value = UserDefaults.standard.double(forKey: silenceTimeoutKey)
        return value > 0 ? value : defaultSilenceTimeout
    }
}
