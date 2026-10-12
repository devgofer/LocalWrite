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

The engine rejects empty model output. Updated 2026-10-13 to match Typeless: deleting fillers, stutters, repeats and self-corrections, adding punctuation, and formatting spoken lists are accepted. The output falls back to the original transcript when it introduces more than 10% new words, changes a number, drops below 30% of the original length, drops an uncertainty word (可能、應該、maybe…), or changes anything in utterances of three words or fewer. Decimal punctuation, symbols, and English word boundaries are preserved by the validation.

Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer sh Scripts/evaluate-refinement.sh` for eight live-model cases (all passing on 2026-10-13). These checks complement deterministic unit tests; they do not establish semantic correctness for all possible speech.
