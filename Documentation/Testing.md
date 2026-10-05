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

The current iOS keyboard target is a platform-compatible extension shell. Apple does not grant third-party custom keyboards microphone access, so voice capture is intentionally tested in the containing LocalWrite app rather than inside the keyboard extension.

### Keyboard extension

- [ ] Install and enable LocalWrite keyboard
- [ ] Globe button switches keyboards
- [ ] Keyboard appears without requesting network/full-access permissions
- [ ] Keyboard does not attempt microphone capture
- [ ] Secure text fields fall back to the system keyboard
- [ ] Keyboard works in compact and regular widths
- [ ] Keyboard does not retain stale state after dismissal

### iOS app voice prototype

- [ ] Microphone permission is granted
- [ ] Speech Recognition permission is granted
- [ ] On-device speech recognition is supported for the selected locale
- [ ] Speech stops automatically after acoustic silence
- [ ] Foundation Model availability is checked before refinement
- [ ] Refined text is displayed correctly

Apple's current custom keyboard documentation explicitly lists no microphone access for keyboards without open access, and custom keyboards remain sandboxed in a separate process. This limitation is a product constraint, not a LocalWrite implementation failure.
