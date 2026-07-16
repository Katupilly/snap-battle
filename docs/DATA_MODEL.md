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

## Identity And Metadata Boundaries

### Musical Result

`PedalSequence`, `PedalHarmony`, `PedalNote`, `PedalSoundProfile`, and the selected `PedalEffect` hold the current musical result: harmony, ordered note events, rests represented by absent events, timing through BPM and step structure, and sound settings. Musical identity must not depend on record identity or generated editorial metadata.

### Record Identity

`PhotoPedal.id` is a UUID identifying one stored record. It is not required to be deterministic.

### Creation Metadata

`PhotoPedal.createdAt` records creation time. It is not required to be deterministic.

### Semantic Metadata

`PhotoPedal.name` and `PhotoPedal.description` originate from `PedalDraft` after Foundation Models generation and validation. They may vary and do not define the musical result. The current code has no fallback metadata path.

## Serialization And Storage

`PhotoPedal` is `Codable`. `PedalStore` serializes the complete final note events and sound settings to `latest-pedal.json`, and stores only the processed PNG cover as `latest-pedal.png`. The original image, input fingerprint, color analysis, Vision data, generator version, board data, and image file URLs are not persisted.

`PedalSequence` decodes missing `soundProfile` as `PedalSoundProfile.legacy`; this is the only current decode compatibility behavior.

## Storage Scope

- **Ephemeral session state:** `PhotoPedalViewModel` holds the currently displayed pedal, cover, selected effect, and synth playback state while the app runs.
- **Latest-pedal storage:** `PedalStore` overwrites one JSON/PNG pair and reloads it on launch.
- **Complete pedal persistence:** not implemented; there is no persistent collection, original-image retention, migration system, or versioned recipe.
- **Gallery:** planned, not implemented.
- **Cache, export, sharing, and boards:** not implemented.

## Invariants And Gaps

- Steps are fixed at 16 and rows at 8.
- `PedalNote.id` is derived from `step-row`.
- Current persisted musical output is replayed rather than regenerated.
- There is no `MusicRecipe` type, generator version, migration system, gallery, or board model.
- `generatorVersion` is planned, not implemented. Its ownership and compatibility contract require a separate approved specification.
