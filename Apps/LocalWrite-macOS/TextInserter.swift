import AppKit
import CoreGraphics
@preconcurrency import ApplicationServices

@MainActor
enum AccessibilityPermission {
    static var isGranted: Bool { AXIsProcessTrusted() }

    static func requestPrompt() {
        guard !isGranted else { return }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
           NSWorkspace.shared.open(url) {
            return
        }
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
            NSWorkspace.shared.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

@MainActor
struct TextInsertionTarget {
    let pid: pid_t
    let element: AXUIElement
    let originalValue: String?
    let selection: CFRange?

    static func capture() throws -> Self {
        guard AccessibilityPermission.isGranted else { throw TextInsertionError.accessibilityPermissionRequired }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw TextInsertionError.noTextField
        }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        guard let value = attribute(application, kAXFocusedUIElementAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { throw TextInsertionError.noTextField }
        let element = value as! AXUIElement
        let role = attribute(element, kAXRoleAttribute) as? String
        let subrole = attribute(element, kAXSubroleAttribute) as? String
        guard subrole != kAXSecureTextFieldSubrole,
              [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role ?? "") else {
            throw TextInsertionError.noTextField
        }
        var range: CFRange?
        if let value = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() {
            let ax = value as! AXValue
            var selected = CFRange()
            if AXValueGetType(ax) == .cfRange, AXValueGetValue(ax, .cfRange, &selected) { range = selected }
        }
        return Self(pid: app.processIdentifier, element: element,
                    originalValue: attribute(element, kAXValueAttribute) as? String, selection: range)
    }

    func validate() throws {
        let current = try Self.capture()
        guard current.pid == pid, CFEqual(current.element, element),
              current.originalValue == originalValue,
              current.selection?.location == selection?.location,
              current.selection?.length == selection?.length else { throw TextInsertionError.targetChanged }
    }

    func confirms(_ text: String) -> Bool {
        guard let value = Self.attribute(element, kAXValueAttribute) as? String,
              let originalValue else { return false }
        if let selection, selection.location >= 0, selection.length >= 0,
           selection.location <= (originalValue as NSString).length,
           selection.length <= (originalValue as NSString).length - selection.location {
            let expected = (originalValue as NSString).replacingCharacters(
                in: NSRange(location: selection.location, length: selection.length), with: text)
            return value == expected
        }
        return value != originalValue && value.contains(text)
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}

/// Restores a temporary clipboard replacement only while it still owns it.
@MainActor
final class PasteboardTransaction {
    private let pasteboard: NSPasteboard
    private let previousItems: [[NSPasteboard.PasteboardType: Data]]
    private let changeCount: Int
    private var restored = false

    init(text: String, pasteboard: NSPasteboard = .general) throws {
        self.pasteboard = pasteboard
        previousItems = pasteboard.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        } ?? []
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            Self.restore(previousItems, to: pasteboard)
            throw TextInsertionError.clipboardUnavailable
        }
        changeCount = pasteboard.changeCount
    }

    func restoreIfUnchanged() {
        guard !restored else { return }
        restored = true
        guard pasteboard.changeCount == changeCount else { return }
        Self.restore(previousItems, to: pasteboard)
    }

    private static func restore(_ items: [[NSPasteboard.PasteboardType: Data]], to board: NSPasteboard) {
        board.clearContents()
        let objects = items.map { values in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        if !objects.isEmpty { board.writeObjects(objects) }
    }
}

@MainActor
enum TextInserter {
    static func insert(_ text: String, into target: TextInsertionTarget) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TextInsertionError.emptyText }
        try target.validate()
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            throw TextInsertionError.eventUnavailable
        }
        let clipboard = try PasteboardTransaction(text: text)
        defer { clipboard.restoreIfUnchanged() }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(target.pid)
        up.postToPid(target.pid)
        // A posted event alone does not prove that the host accepted the text.
        for _ in 0..<10 {
            try await Task.sleep(for: .milliseconds(100))
            if target.confirms(text) { return }
        }
        throw TextInsertionError.unconfirmed
    }
}

enum TextInsertionError: LocalizedError {
    case accessibilityPermissionRequired, noTextField, targetChanged
    case clipboardUnavailable, eventUnavailable, emptyText, unconfirmed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired: "請在「系統設定 → 隱私權與安全性 → 輔助使用」中允許 LocalWrite，然後重新啟動 App。"
        case .noTextField: "Focus an editable text field, then use the shortcut."
        case .targetChanged: "The text field changed. Your text is saved in the LocalWrite menu."
        case .clipboardUnavailable: "The clipboard is unavailable. Your text is saved in the LocalWrite menu."
        case .eventUnavailable: "Could not send Paste. Your text is saved in the LocalWrite menu."
        case .emptyText: "There is no text to insert."
        case .unconfirmed: "Check the text field before retrying. Your text is saved in the LocalWrite menu."
        }
    }
}
