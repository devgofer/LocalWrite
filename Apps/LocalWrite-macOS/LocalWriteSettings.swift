import AppKit
import Carbon

/// A global shortcut: a virtual key code plus Carbon modifier flags.
struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))

    init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }

    /// Nil when the event has no modifier (a bare letter would block typing), except F-keys.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        let code = UInt32(event.keyCode)
        let functionKey = Self.functionKeys[Int(code)] != nil
        guard carbon & ~UInt32(shiftKey) != 0 || functionKey else { return nil }
        self.init(keyCode: code, modifiers: carbon)
    }

    var displayName: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + Self.keyName(keyCode)
    }

    private static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18"
    ]
    private static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓"
    ]

    private static func keyName(_ code: UInt32) -> String {
        if let name = functionKeys[Int(code)] ?? namedKeys[Int(code)] { return name }
        // Ask the current keyboard layout which character the key produces.
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "Key \(code)" }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { bytes in
            UCKeyTranslate(bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress, UInt16(code), UInt16(kUCKeyActionDisplay),
                           0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, 4, &length, &characters)
        }
        guard status == noErr, length > 0 else { return "Key \(code)" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}

enum LocalWriteSettings {
    private static let keyCodeKey = "shortcutKeyCode"
    private static let modifiersKey = "shortcutModifiers"

    static var shortcut: Shortcut {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: keyCodeKey) != nil else { return legacyShortcut ?? .default }
            return Shortcut(keyCode: UInt32(defaults.integer(forKey: keyCodeKey)),
                            modifiers: UInt32(defaults.integer(forKey: modifiersKey)))
        }
        set {
            UserDefaults.standard.set(Int(newValue.keyCode), forKey: keyCodeKey)
            UserDefaults.standard.set(Int(newValue.modifiers), forKey: modifiersKey)
        }
    }

    /// Earlier builds stored only a modifier name for ⌥/⌃/⌘ + Space.
    private static var legacyShortcut: Shortcut? {
        switch UserDefaults.standard.string(forKey: "shortcutModifier") {
        case "control": Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey))
        case "command": Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey))
        default: nil
        }
    }
}
