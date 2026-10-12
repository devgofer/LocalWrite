import AppKit
import Carbon

@MainActor
final class GlobalShortcutMonitor {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var onTrigger: (@MainActor () -> Void)?

    func start(onTrigger: @escaping @MainActor () -> Void) throws {
        stop()
        self.onTrigger = onTrigger
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor [weak monitor] in monitor?.onTrigger?() }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { stop(); throw ShortcutError.unavailable }
        let shortcut = LocalWriteSettings.shortcut
        let id = EventHotKeyID(signature: 0x4C575254, id: 1)
        guard RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &hotKey) == noErr else {
            stop()
            throw ShortcutError.unavailable
        }
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
        onTrigger = nil
    }

    isolated deinit { stop() }
}

private enum ShortcutError: LocalizedError {
    case unavailable
    var errorDescription: String? { "This shortcut is already in use. Choose another one in Settings." }
}
