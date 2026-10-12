# iOS keyboard acceptance criteria — 2026-10-11

The user requires dictation to stay in the host text field for the entire interaction:

1. Delete, microphone, return keys.
2. First microphone tap starts listening without opening LocalWrite or another app.
3. Second tap stops, refines through Foundation Models, and inserts directly into that field.
4. A manually enabled recording assistant, visible app handoff, and manual return are rejected.

The currently installed Link-based launch implementation does not satisfy these criteria. It remains an incomplete device-test implementation, even if its crashes are fixed. Do not ask the user to validate the rejected app-switching flow again as acceptance testing.

## Unresolved implementation requirement

A supported, reliable keyboard-triggered route must activate the recording app in the background while keeping the host foreground. No such route has been validated in this project. Do not replace the microphone with a no-op or status-only button and describe that as a fix.

Evidence reviewed:

- Typeless's official explanation describes both direct dictation and an app-switching path; it does not disclose an API LocalWrite can use to reproduce the direct path from a cold state: https://www.typeless.com/help/release-notes/ios/when-does-app-switching-happen
- Apple's AudioRecordingIntent requires a Live Activity during recording. Its existence alone does not establish that a custom keyboard can invoke it as a system-authorized background action: https://developer.apple.com/documentation/appintents/audiorecordingintent
- Apple DTS explains that ordinary background audio activation is restricted; communication frameworks are specifically for communication apps: https://developer.apple.com/forums/thread/816408
- Outspoken's developer documents a warm, already-active microphone path, an optional user-created Shortcut path, and a foreground fallback. Those prerequisites/fallbacks do not establish compliance with this user's requirement: https://www.useoutspoken.com/blog/the-keyboard-is-a-remote-control

The unresolved requirement is background activation, before speech recognition or Foundation Models. Avoid claiming that changing the refinement model will resolve it, or that Typeless's undisclosed implementation is known.
