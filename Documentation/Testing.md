# Testing

## macOS manual QA

Run on a compatible Apple Intelligence Mac.

### Permissions

- [ ] Microphone permission granted
- [ ] Speech Recognition permission granted
- [ ] Accessibility permission granted
- [ ] Foundation Model reports available

### Core flow

- [ ] Focus a text field in Notes
- [ ] Press Option-Space
- [ ] Capsule appears
- [ ] Capsule shows Listening
- [ ] Speak one sentence
- [ ] Stop speaking
- [ ] Capsule changes to Refining
- [ ] Capsule changes to Writing
- [ ] Refined text is inserted automatically
- [ ] Capsule disappears
- [ ] Clipboard content is restored

### Voice preservation

Test examples:

1. 「嗯我覺得這個應該可以吧」
2. 「我不知道欸可能明天比較方便」
3. "I think we can ship this tomorrow but I'm not one hundred percent sure"
4. 「這個 button 我覺得可以放右邊」
5. 「等一下我先看一下，不行的話我們禮拜四再約」

The output should become easier to read without becoming formal or changing the speaker's intent.

### Failure cases

- [ ] Model unavailable
- [ ] Speech permission denied
- [ ] Accessibility permission denied
- [ ] Empty speech
- [ ] Unsupported speech locale
- [ ] Focused app refuses paste
- [ ] Long transcript
- [ ] Rapid repeated shortcut presses

## iOS manual QA

- [ ] Install and enable LocalWrite keyboard
- [ ] Globe button switches keyboards
- [ ] Microphone button starts recording
- [ ] Speech stops automatically after silence
- [ ] Foundation Model refines the transcript
- [ ] textDocumentProxy.insertText() inserts directly at cursor
- [ ] Secure text fields fall back to the system keyboard
- [ ] Keyboard works in compact and regular widths
- [ ] Keyboard does not retain previous transcript after insertion

Apple notes that custom keyboards run in a separate process with memory limits, so memory usage should be checked on multiple device models.
