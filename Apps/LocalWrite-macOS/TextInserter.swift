import AppKit
import CoreGraphics

enum TextInserter {
    static func insert(_ text: String) throws {
        guard AXIsProcessTrusted() else {
            throw TextInsertionError.accessibilityPermissionRequired
        }

        let pasteboard = NSPasteboard.general
        let previousItems = pasteboard.pasteboardItems?.map { item in
            var values: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    values[type] = data
                }
            }
            return values
        } ?? []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            pasteboard.clearContents()
            for item in previousItems {
                let pasteboardItem = NSPasteboardItem()
                for (type, data) in item {
                    pasteboardItem.setData(data, forType: type)
                }
                pasteboard.writeObjects([pasteboardItem])
            }
        }
    }
}

enum TextInsertionError: LocalizedError {
    case accessibilityPermissionRequired

    var errorDescription: String? {
        "Enable Accessibility access for LocalWrite in System Settings."
    }
}
