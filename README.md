# LocalWrite

**Your words. Written locally.**

LocalWrite is an on-device voice writing tool for Apple platforms.

Speak naturally. LocalWrite captures the transcript, lightly cleans it up with Apple's on-device Foundation Model, and inserts the result directly into the text field you're already using.

No extra "Insert" step.

## Product direction

### macOS

The primary interaction is intentionally tiny:

1. Focus any text field.
2. Trigger LocalWrite with the configured keyboard shortcut.
3. A small capsule appears near the active writing area.
4. Speak naturally.
5. Stop speaking; after a short silence, LocalWrite finishes listening automatically.
6. The transcript is lightly refined on-device.
7. The refined text is inserted automatically.
8. The capsule disappears.

The visual direction is inspired by the simplicity of Typeless: one compact capsule, minimal controls, almost no UI chrome. The product should feel like a native interaction rather than another editor window.

### iOS

LocalWrite is a three-key voice keyboard: **Delete · Microphone · Return**.

Tap the keyboard microphone to open LocalWrite and start recording. Return to the original text field using the system back control, then tap the microphone again to finish, refine on-device, and insert. Long-press Return to switch keyboards. Audio capture stops when recording ends. Automatic return to the host app remains unimplemented; this is a device-test build, and the intended uninterrupted keyboard experience remains a work in progress.

The helper and keyboard use a shared App Group, requiring Full Access for the keyboard. See [setup and validation status](Documentation/Keyboard-and-Permissions-2026-10-08.md).

## Core principle

LocalWrite should **clean up speech, not rewrite the person**.

It should:

- preserve meaning
- preserve tone and personality
- remove obvious speech fillers
- fix punctuation
- fix obvious grammar issues
- split long spoken sentences when useful
- preserve intentional wording
- never invent information
- never summarize
- never make writing unnecessarily formal
- preserve intentional mixed-language wording

Example:

> Raw: 「嗯我覺得這個應該可以吧，只是可能要再看一下時間，如果明天不行的話禮拜四也可以」

> LocalWrite: 「我覺得這個應該可以，只是可能要再看一下時間。如果明天不行的話，週四也可以。」

Not:

> 「我認為此方案基本可行，但仍需進一步確認時間安排……」

## Architecture

```
Audio
  ↓
Speech Recognition
  ↓
Raw Transcript
  ↓
LocalWriteCore
  ↓
Apple Foundation Models
  ↓
Light Refinement
  ↓
Insert into active text field
```

The shared core deliberately keeps speech recognition separate from language refinement so either layer can evolve independently.

```
LocalWrite/
├── Package.swift
├── project.yml
├── README.md
├── Sources/
│   └── LocalWriteCore/
│       ├── AI/
│       ├── Models/
│       └── Speech/
├── Tests/
│   └── LocalWriteCoreTests/
├── Apps/
│   ├── LocalWrite-macOS/
│   └── LocalWrite-iOS/
└── Documentation/
```

## Milestones

- [x] Milestone 1 — shared core + Foundation Models proof of concept
- [x] Milestone 2 — macOS capsule + global shortcut
- [x] Milestone 3 — speech recognition → refinement → automatic insertion
- [x] Milestone 4 — iOS custom keyboard foundation (voice capture constrained by platform)
- [x] Milestone 5 — settings, permission onboarding, and evaluation foundations
- [ ] Milestone 6 — Xcode target assembly, final polish, and device validation

## Current MVP interaction

### macOS

**Configured Modifier + Space → speak → silence → automatic insertion**

The default shortcut is **Option + Space**. You can change the modifier in Settings. The capsule is intentionally the only visible interaction. There is no confirmation screen and no Insert button.

### iOS

**Keyboard microphone → recording app → return to text field → microphone → refinement → insertion**

The keyboard creates a one-use launch request, opens its recording app with a SwiftUI Link, then exchanges stop/cancel commands and results through a local App Group. No manual five-minute session is required. Results are inserted only into the requesting, unchanged text field.

## Requirements

- Xcode with Foundation Models support
- macOS/iOS 26 or later
- A compatible Apple Intelligence device for the on-device model
- XcodeGen if you want to generate the Xcode project from `project.yml`

The Foundation Models framework exposes Apple's on-device language model through `SystemLanguageModel`. Model availability must be checked at runtime.

Speech recognition availability and supported on-device languages can vary by device and locale. LocalWrite requests on-device speech recognition where supported, and refuses to start if the selected recognizer cannot provide on-device recognition.

## Xcode project

The repository keeps reusable logic in the Swift Package and describes the Apple application targets in `project.yml`.

Generate the Xcode project with:

```bash
xcodegen generate
open LocalWrite.xcodeproj
```

See [Documentation/Xcode.md](Documentation/Xcode.md) for target and signing notes.

## Privacy

LocalWrite is designed around an on-device-first architecture. The refinement layer uses Apple's on-device Foundation Model when it is available. LocalWrite does not require a cloud LLM for its core refinement flow.

On macOS, speech recognition is requested only when the voice feature is used, and final text is inserted through a temporary pasteboard bridge that restores the previous pasteboard contents.

On iOS, the keyboard extension is intentionally non-networked. Voice capture is kept out of the keyboard extension because Apple does not grant third-party custom keyboards microphone access.

## Status

The Mac app is signed and its Accessibility grant was verified in the running process after replacing a stale code-signature permission record. The iOS app and keyboard are signed and installed on a connected iPhone 17. End-to-end speech/keyboard verification is still in progress.

The highest-value validation targets are:

1. macOS microphone and Speech Recognition permissions
2. macOS Accessibility permission
3. real acoustic silence detection
4. Foundation Model availability
5. global shortcut behavior
6. pasteboard insertion across multiple host apps
7. iOS keyboard installation and switching
8. iOS keyboard memory/resource behavior
