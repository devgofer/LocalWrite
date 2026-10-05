# macOS UX

LocalWrite is not a transcription window.

## Interaction

```
Idle
  ↓
Configured Modifier + Space
  ↓
Capsule appears
  ↓
Listening
  ↓
User stops speaking
  ↓
Short silence timeout
  ↓
Refining
  ↓
Automatic insertion
  ↓
Capsule disappears
```

There is no normal Insert button.

## Capsule

The capsule is a small floating panel:

- translucent material
- rounded capsule shape
- subtle listening indicator
- optional live transcript preview
- compact refining/writing state

No dashboard, editor, or persistent window.

## Automatic insertion

After refinement, LocalWrite temporarily places the final text on the macOS pasteboard, sends Command-V to the focused application, then restores the previous pasteboard contents.

This requires Accessibility permission.

If insertion fails, the capsule shows the error instead of silently dropping the text.

## Shortcut

The default shortcut is **Option-Space**. The modifier can be changed in LocalWrite Settings to Option, Control, or Command.

The key remains Space in this MVP.
