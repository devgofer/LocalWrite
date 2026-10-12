# LocalWrite vs Typeless: gaps and modification plan — 2026-10-13

Benchmark behavior (Typeless):

- **Mac:** hold a key (Fn by default) to talk, release to insert; double-tap for hands-free. Works in any app, including Slack, Chrome and other web/Electron fields. AI removes fillers, repetitions and self-corrections ("明天，不對，後天" → "後天"), formats lists, keeps your tone.
- **iOS keyboard:** a Speak button inside a real keyboard. Outlined mic = the app must open once to get the microphone; solid mic = dictate directly in the host field with no switch ([Typeless help](https://www.typeless.com/help/release-notes/ios/when-does-app-switching-happen)). After that one switch, every later dictation stays in the host app. Result can be polished or translated before it lands.

## Why the iOS keyboard is unusable today

1. **Every dictation leaves the host app.** The mic opens LocalWrite via a Link, records, then the user must swipe back and tap again. After each result, the app tears down the audio session (`KeyboardVoiceHelper.stopCapture`, and the `.start` command is deliberately ignored at `KeyboardVoiceHelper.swift` `tick()`), so the next dictation bounces again. Typeless bounces once per session, not once per sentence.
2. **The root constraint was mis-specified.** `Documentation/Keyboard-Requirements.md` demands that a cold first tap records without opening the app. iOS keyboard extensions cannot use the microphone, so no app can do this, Typeless included. Codex removed the only workable design (a warm background session) to chase an impossible requirement.
3. **Insertion is refused too often.** The result is inserted only if `documentContextBeforeInput`/`AfterInput` are byte-identical to before the app switch (`KeyboardViewController.swift:184`). Hosts commonly return different or truncated context after a switch, so the result is silently cancelled. Device logs show a pending request that was never consumed.
4. **It isn't a keyboard.** Three keys: Delete, Mic, Return. No space, punctuation, globe key, transcript preview, undo, or polish/translate choice. `needsInputModeSwitchKey` is ignored.
5. **Fragile IPC.** Both sides poll JSON files every 100–150 ms with 4 s heartbeats; a brief stall cancels the session.
6. **Hard failure when the model is busy.** If Foundation Models is unavailable (or throttled in the background), the whole dictation fails instead of inserting the raw transcript.

## Gaps on Mac

1. **Pressing the shortcut again cancels instead of finishing** (`LocalWriteController.toggleListening`): your speech is discarded. Finishing only happens through a 1.25 s silence auto-stop (`SpeechSession.tick`), which cuts people off mid-thought.
2. **No hold-to-talk.** Only a Carbon Option+Space toggle; Fn and key-release can't be detected that way.
3. **Refuses most text fields.** Insertion requires AX role TextField/TextArea/ComboBox, so web and Electron apps (Slack, Chrome, Notion) fail with "no text field".
4. **"AI cleanup" is effectively punctuation only.** `RefinementPolicy.preserveWording` reverts to the original whenever any word changes, except a single leading 嗯/呃/um. Mid-sentence fillers, repeats and self-corrections are never removed.
5. No translate mode, no language choice (zh-TW is hard-coded), no personal dictionary, no history.

## Plan (priority order)

v1 scope (nina, 2026-10-12): clean, minimal Typeless-like UI; only speech cleanup and translation. On iOS the product is the keyboard extension, usable in any app; the containing app only exists to hold the microphone session and settings, as iOS requires.

All cleanup and translation runs on Apple's Foundation Models framework (`SystemLanguageModel`) on both Mac and iOS; no other model or server. On iOS the model runs in the LocalWrite app's warm session, not inside the keyboard extension, whose memory limit is too small for it. If Foundation Models is unavailable or throttled while the app is in the background, LocalWrite inserts the raw transcript and says so rather than switching models.

### Phase 1 — make the iOS keyboard usable (Typeless-style warm session)

1. **Warm session in the app.** First mic tap (outlined mic) opens LocalWrite once; the app starts an `AVAudioSession` (`.playAndRecord`, `.mixWithOthers`) and keeps `AVAudioEngine` running in the background (existing `audio` background mode), discarding buffers while idle. The app shows "swipe back to your app" and the keyboard turns the mic solid. Session lasts a user-chosen time (5 min / 15 min / 1 h / until stopped), ends on interruption, and the orange mic indicator stays visible as the honest signal.
2. **Direct dictation while warm.** Keyboard tap → `start` command → app begins a recognition request on the live engine; tap again → `finish` → refine → result. No app switch.
3. **Event-driven IPC.** Keep the App Group files for state, but signal with Darwin notifications (`CFNotificationCenterGetDarwinNotifyCenter`) instead of 150 ms polling; relax heartbeats.
4. **Reliable insertion.** Insert when the document identifier matches; drop the exact before/after text check. Keep one-shot claim to prevent double insert.
5. **Minimal keyboard UI (v1 scope: cleanup + translate only).** One large mic with the live transcript above it, a two-way toggle Clean / Translate (target language set in the app), plus only Space, Delete (repeat on hold), Return and the globe key when `needsInputModeSwitchKey`. No history, dictionary or extra rows in v1.
6. **Fallback.** If the model is unavailable or throws, insert the raw transcript and say so.
7. Rewrite `Keyboard-Requirements.md` to the warm-session acceptance criteria; device test on iPhone.

### Phase 2 — cleanup quality (shared by Mac and iOS)

1. Replace the all-or-nothing word check with a guarded policy: allow deletions of fillers anywhere, repeated words, and self-corrections; still reject added content, translation (when not asked) or summarizing (length/novel-token checks).
2. Generable structured output (`@Generable`) for polish and translate; translate mode with a target language.
3. Grow `Scripts/EvaluateRefinement.swift` into a fixed zh-TW/English/mixed corpus and gate changes on it.

### Phase 3 — Mac parity

1. Hold-to-talk via `CGEventTap`/`flagsChanged` (Fn or right Option), release to finish; double-tap for hands-free; second press finishes instead of cancels; no silence auto-stop while held.
2. Insert anywhere: try AX first, otherwise paste into the frontmost app with clipboard restore (already implemented in `TextInserter`), only refusing secure fields.
3. Raw fallback and a Clean / Translate choice in the menu bar; nothing else in v1.

## Decision needed

The warm session means the first dictation of a session opens LocalWrite once and you swipe back; later dictations stay in the host app. This is how Typeless works and the only route iOS allows, but it contradicts the 2026-10-11 requirement that the app never opens.
