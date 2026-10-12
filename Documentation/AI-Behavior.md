# AI Behavior

LocalWrite is a speech cleanup layer, not a writing replacement.

## Allowed changes

- remove obvious filler words
- normalize punctuation
- fix obvious grammar mistakes
- split run-on spoken sentences
- preserve natural contractions and casual wording
- keep Chinese and English mixed language intact
- normalize obvious spoken date/number phrasing when the meaning is unambiguous

## Forbidden changes

- adding facts
- summarizing
- changing the speaker's opinion
- changing certainty
- making casual text corporate
- replacing personality with generic AI prose
- inventing missing words or context
- translating unless explicitly requested

## Golden rule

If the user said it naturally and it is already understandable, **leave it alone**.

The Foundation Models prompt is intentionally short because Apple's current guidance recommends concise, imperative instructions and notes that prompts contribute to the model's context size.


## Result validation (2026-10-06)

The engine rejects empty model output. Updated 2026-10-13 to match Typeless (fillers, repetition, self-correction, formatting, word choice). The output falls back to the original transcript when more than 40% of its words are new, a number value changes or appears, it shrinks below 30% or grows past 150% of the original, it switches between Chinese and English, it drops an uncertainty word (可能、應該、maybe…), or the utterance is three words or fewer. Decimal punctuation, symbols, and English word boundaries are preserved by the validation.

Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer sh Scripts/evaluate-refinement.sh` for 14 live-model cases covering the five Typeless features (13 pass on 2026-10-13; "三張不是四張" without commas keeps the first number). These checks complement deterministic unit tests; they do not establish semantic correctness for all possible speech.
