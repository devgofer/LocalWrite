# iOS keyboard acceptance criteria — 2026-10-13

Replaces the 2026-10-11 criteria. nina approved the Typeless-style warm session on 2026-10-12: iOS keyboard extensions cannot use the microphone, so the first dictation of a session opens LocalWrite once and later dictations stay in the host app.

1. The keyboard has only: mode toggle (整理 / 翻譯成…), a status line with the live transcript, one mic, and Globe (when iOS asks for it), Space, Delete (repeats on hold), Return.
2. Cold (outlined mic): one tap opens LocalWrite, which activates the audio session and keeps its audio engine running with the input muted to stay ready for the chosen time (5 / 15 / 60 minutes). Recording only happens between start and finish. The app tells the user to swipe back along the bottom edge; there is no automatic return.
3. Warm (solid mic): tap to start, tap again to finish. The text is cleaned or translated by Apple Foundation Models in the app and inserted into the same field. No app switch.
4. If Foundation Models fails, the raw transcript is inserted and the status line says so.
5. A result is inserted once and only into the field it was dictated in. Dismissing the keyboard cancels a dictation in progress.
6. The session ends on timeout, on 停止待命 in the app, or when another app interrupts audio; the mic then shows outlined again.
