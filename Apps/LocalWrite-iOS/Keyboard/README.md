# LocalWrite keyboard

iOS keyboards cannot record audio, so the LocalWrite app holds a warm microphone session (`App/VoiceSessionHost.swift`) and the keyboard drives it.

- Outlined mic: no session. Tapping writes a one-use launch ticket to the App Group and opens `localwrite://session/<id>` through a SwiftUI Link. The app activates its audio session in the foreground and starts a picture-in-picture window (`App/PictureInPictureKeeper.swift`) that keeps it running. The microphone (`AVAudioEngine` input tap) runs only from a start command to finish.
- Solid mic: the keyboard writes a `KeyboardCommand` (start / finish / cancel, with mode and target language) and posts a Darwin notification. The app publishes `VoiceState` (with a 2 s heartbeat) and posts back. The keyboard inserts a finished result once, into the same document.
- Clean and translate both run on Foundation Models in the app. On failure the raw transcript is inserted.

Both targets use App Group `group.com.devgofer.LocalWrite`; the keyboard requires Full Access. Acceptance criteria: `Documentation/Keyboard-Requirements.md`.
