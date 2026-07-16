# Data Model

## Current Domain Types

`Domain/Pedal/Pedal.swift` defines the persisted model.

| Type | Purpose | Status |
| --- | --- | --- |
| `PhotoPedal` | One saved generated result | Persisted as the latest pedal |
| `PedalSequence` | Musical result and sound profile | Persisted inside `PhotoPedal` |
| `PedalHarmony` | Root pitch class, scale, BPM | Persisted |
| `PedalNote` | One grid note: step, row, MIDI note, velocity | Persisted |
| `PedalSoundProfile` | Gate, octave range, waveform, effect presets and mixes | Persisted |
| `PedalDraft` | Foundation Models name/description output | Transient |

`PhotoPedal` stores `id`, `name`, `description`, `sequence`, `effect`, `createdAt`, and `coverFilename`. The selected effect and both stored effect mixes are saved. `updating` creates a replacement value rather than mutating the model.

## Serialization And Storage

`PhotoPedal` is `Codable`. `PedalStore` serializes the complete final note events and sound settings to `latest-pedal.json`, and stores only the processed PNG cover as `latest-pedal.png`. The original image, input fingerprint, color analysis, Vision data, generator version, board data, and image file URLs are not persisted.

`PedalSequence` decodes missing `soundProfile` as `PedalSoundProfile.legacy`; this is the only current decode compatibility behavior.

## Invariants And Gaps

- Steps are fixed at 16 and rows at 8.
- `PedalNote.id` is derived from `step-row`.
- Current persisted musical output is replayed rather than regenerated.
- There is no `MusicRecipe` type, generator version, migration system, gallery, or board model.
- A future versioned recipe must preserve existing saved output; it cannot rely on recalculation alone.
