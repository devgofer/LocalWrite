# LocalWrite keyboard

iOS keyboards cannot record audio, so the LocalWrite app holds a warm microphone session (`App/VoiceSessionHost.swift`) and the keyboard drives it.

- Outlined mic: no session. Tapping writes a one-use launch ticket to the App Group and opens `localwrite://session/<id>` through a SwiftUI Link. The app activates its audio session in the foreground and plays silence (`App/BackgroundKeepAlive.swift`) so iOS keeps it running. The microphone (`AVAudioEngine` input tap) runs only from a start command to finish.
- Solid mic: the keyboard writes a `KeyboardCommand` (start / finish / cancel, with mode and target language) and posts a Darwin notification. The app publishes `VoiceState` (with a 2 s heartbeat) and posts back. The keyboard inserts a finished result once, into the same document.
- Clean and translate both run on Foundation Models in the app. On failure the raw transcript is inserted.

Both targets use App Group `group.com.devgofer.LocalWrite`; the keyboard requires Full Access. Acceptance criteria: `Documentation/Keyboard-Requirements.md`.

Automatic return (experimental): when the cold mic opens LocalWrite, the keyboard tries to identify the host app (`Keyboard/HostApp.swift`) and the app switches back to it (`App/HostReturn.swift`). Both use undocumented iOS interfaces, guarded so they fail silently; App Review may reject them. Results are logged to `diagnostics.log` in the App Group cache.
