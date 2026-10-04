# LocalWrite Architecture

## Milestone 1

Milestone 1 establishes the shared AI core before building platform UI.

### Responsibilities

```
LocalWriteEngine
       │
       └── FoundationModelsEngine
               │
               └── Apple SystemLanguageModel
```

The engine owns the refinement behavior. It does not know anything about microphones, keyboards, pasteboards, windows, or text insertion.

That separation is intentional.

### Why this matters

The same refinement engine will be used by:

- macOS capsule
- macOS text insertion layer
- iOS keyboard extension

This keeps product behavior consistent across platforms.

## Availability

Foundation Models availability is checked at runtime through `SystemLanguageModel.default.isAvailable`.

A device may be unable to use the model because the hardware, region, or model readiness does not satisfy Apple's requirements. The UI layer should turn that state into a clear product message instead of assuming the model exists.

## Next milestone

Milestone 2 adds the macOS experience:

```
Focused text field
      ↓
Global shortcut
      ↓
Capsule appears
      ↓
Recording state
      ↓
Transcript
      ↓
Foundation Models refinement
      ↓
Automatic insertion
      ↓
Capsule disappears
```

There should be no confirmation screen and no separate Insert button in the normal flow.
