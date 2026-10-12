# LocalWrite keyboard

Three keys: Delete, Microphone, Return. Long-press Return to switch keyboards.

Tapping the microphone creates a fresh App Group launch ticket and uses a SwiftUI Link to open the recording app. The app consumes the ticket and starts recording automatically after permissions are available. Use the system return control to return to the original text field, then tap the keyboard microphone again to stop, refine with Foundation Models and insert. Automatic return to the host app remains unfinished.

The app stops microphone capture when dictation ends. The extension retains a pending request across its own app launch, and can restore it after controller recreation only when the document identifier matches. Results are inserted once and only when surrounding text is unchanged. Pending context is cleared on completion/cancel. Stale requests expire; files can persist after a crash until overwritten.

Both iOS targets use App Group `group.com.devgofer.LocalWrite`; the keyboard requires Full Access. See `Documentation/Keyboard-and-Permissions-2026-10-08.md` for validation status.
