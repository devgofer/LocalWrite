# LocalWrite keyboard

iOS keyboards cannot record audio, so the LocalWrite app holds a warm microphone session (`App/VoiceSessionHost.swift`) and the keyboard drives it.

- Outlined mic: no session. Tapping writes a one-use launch ticket to the App Group and opens `localwrite://session/<id>` through a SwiftUI Link. The app starts its audio engine in the foreground (iOS refuses to start recording from the background) and keeps it running, which keeps the app alive. Between dictations the input is muted with `AVAudioApplication.setInputMuted` and buffers are discarded.
- Solid mic: the keyboard writes a `KeyboardCommand` (start / finish / cancel, with mode and target language) and posts a Darwin notification. The app publishes `VoiceState` (with a 2 s heartbeat) and posts back. The keyboard inserts a finished result once, into the same document.
- Clean and translate both run on Foundation Models in the app. On failure the raw transcript is inserted.

Both targets use App Group `group.com.devgofer.LocalWrite`; the keyboard requires Full Access. Acceptance criteria: `Documentation/Keyboard-Requirements.md`.

Automatic return (experimental): when the cold mic opens LocalWrite, the app asks the system "back to <app>" breadcrumb to navigate back, or opens the host bundle ID when the keyboard could identify it (`App/HostReturn.swift`, `Keyboard/HostApp.swift`). Both use undocumented iOS interfaces, guarded so they fail silently; App Review may reject them. Results are logged to `diagnostics.log` in the App Group cache.
