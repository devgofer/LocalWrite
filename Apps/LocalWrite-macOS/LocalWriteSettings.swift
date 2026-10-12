import Foundation

enum LocalWriteSettings {
    static let shortcutModifierKey = "shortcutModifier"
    static let shortcutKeyStorageKey = "shortcutKey"

    static let defaultShortcutModifier = "option"
    static let defaultShortcutKey = "Space"

    static var shortcutModifier: String {
        UserDefaults.standard.string(forKey: shortcutModifierKey) ?? defaultShortcutModifier
    }

    static var shortcutKey: String {
        UserDefaults.standard.string(forKey: shortcutKeyStorageKey) ?? defaultShortcutKey
    }
}
