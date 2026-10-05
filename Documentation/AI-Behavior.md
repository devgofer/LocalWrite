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
