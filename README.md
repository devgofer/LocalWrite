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

LocalWrite ships as a custom keyboard foundation. The keyboard provides the microphone interaction while the shared LocalWriteCore package handles refinement.

1. Open the LocalWrite keyboard.
2. Tap the microphone.
3. Speak naturally.
4. After a short silence, listening finishes automatically.
5. LocalWrite refines the transcript.
6. The keyboard inserts the result through `textDocumentProxy.insertText()`.

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
- [x] Milestone 4 — iOS custom keyboard foundation
- [x] Milestone 5 — settings, permission onboarding, and evaluation foundations
- [ ] Milestone 6 — final polish, Xcode target assembly, and device validation

## Current MVP interaction

### macOS

**Configured Modifier + Space → speak → silence → automatic insertion**

The default shortcut is **Option + Space**. You can change the modifier in Settings. The capsule is intentionally the only visible interaction. There is no confirmation screen and no Insert button.

### iOS

**Open LocalWrite keyboard → tap microphone → speak → silence → automatic insertion**

The keyboard inserts through `textDocumentProxy.insertText()` at the current cursor position.

## Requirements

- Xcode with Foundation Models support
- macOS/iOS 26 or later
- A compatible Apple Intelligence device for the on-device model

The Foundation Models framework exposes Apple's on-device language model through `SystemLanguageModel`. Model availability must be checked at runtime.

Speech recognition availability and supported on-device languages can vary by device and locale. LocalWrite requests on-device speech recognition where supported.

## Privacy

LocalWrite is designed around an on-device-first architecture. The refinement layer uses Apple's on-device Foundation Model when it is available. LocalWrite does not require a cloud LLM for its core refinement flow.

Speech recognition is requested only when the voice feature is used. The app declares the required microphone and speech-recognition usage descriptions.

## Status

The core architecture is implemented, but this repository still requires final Xcode target assembly and real-device validation. In particular, macOS Accessibility permissions, microphone/speech authorization, Foundation Model availability, global shortcut behavior, pasteboard insertion, and the iOS keyboard extension should be validated on physical Apple devices.
