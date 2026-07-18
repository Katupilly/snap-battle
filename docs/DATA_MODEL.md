# Data Model

## Current Domain Types

`Domain/Pedal/Pedal.swift` defines the persisted model.

| Type | Purpose | Status |
| --- | --- | --- |
| `PhotoPedal` | One saved generated result | Persisted as a UUID-associated collection record |
| `PedalSequence` | Musical result and sound profile | Persisted inside `PhotoPedal` |
| `PedalHarmony` | Root pitch class, scale, BPM | Persisted |
| `PedalNote` | One grid note: step, row, MIDI note, velocity | Persisted |
| `PedalSoundProfile` | Gate, octave range, waveform, effect presets and mixes | Persisted |
| `PedalDraft` | Foundation Models or fallback name/description output | Transient |
| `Pedalboard` | One ordered list of pedal references persisted as a UUID-associated document | Persisted separately from `PhotoPedal` |
| `PedalboardEntry` | Reference to a `PhotoPedal.id` plus a stable entry identity | Persisted inside `Pedalboard` |
| `PedalboardDocument` | Schema envelope around `Pedalboard` (`schemaVersion = 1`) | Persisted |

`PhotoPedal` stores `id`, `name`, `description`, `sequence`, `effect`, `createdAt`, and `coverFilename`. The selected effect and both stored effect mixes are saved. `updating` creates a replacement value rather than mutating the model. Semantic enrichment may replace only `name` and `description` for an existing `id`.

## Identity And Metadata Boundaries

### Musical Result

`PedalSequence`, `PedalHarmony`, `PedalNote`, `PedalSoundProfile`, and the selected `PedalEffect` hold the current musical result: harmony, ordered note events, rests represented by absent events, timing through BPM and step structure, and sound settings. Musical identity must not depend on record identity or generated editorial metadata.

### Record Identity

`PhotoPedal.id` is a UUID identifying one stored record. It is not required to be deterministic.

### Creation Metadata

`PhotoPedal.createdAt` records creation time. It is not required to be deterministic.

### Semantic Metadata

`PhotoPedal.name` and `PhotoPedal.description` are initially the valid fallback metadata: name `Photo Pedal`; description `A photo-generated sound pedal.`. The fallback record is persisted and playable before semantic enrichment runs. If Foundation Models metadata later succeeds and validates, `PedalStore` updates only `name` and `description` for the same `PhotoPedal.id`. If enrichment is unavailable, refused, failed, empty, invalid, stale, cancelled, or unable to update the existing record, the fallback remains. These values do not define the musical result.

## Serialization And Storage

`PhotoPedal` remains `Codable` with its existing schema. `PedalStore` serializes the complete final note events and sound settings to `<PhotoPedal.id>.json` and stores the processed cover as `<PhotoPedal.id>.png`; collection lookup derives that path from identity rather than `coverFilename`. The legacy `latest-pedal.json`/`latest-pedal.png` pair remains readable and is preserved after idempotent migration. The original image, input fingerprint, color analysis, Vision data, generator version, board data, and image file URLs are not persisted.

`PedalSequence` decodes missing `soundProfile` as `PedalSoundProfile.legacy`; this is the only current decode compatibility behavior.

## Storage Scope

- **Ephemeral session state:** `PhotoPedalViewModel` holds the currently displayed pedal, cover, selected effect, and synth playback state while the app runs.
- **Collection storage:** `PedalStore` loads, validates, orders, saves, deletes, and migrates local pedal pairs.
- **Pedalboard storage:** `PedalboardStore` loads, validates, orders, saves, and deletes pedalboard documents in `Application Support/pedalboards/`. It only references pedals by `StoredPedal.ID` and never reads, writes, or deletes `PedalStore` records.
- **Gallery:** presents valid persisted pedals; invalid pairs are excluded without blocking valid records.
- **Cache, export, sharing, and boards playback:** not implemented.

## Invariants And Gaps

- Steps are fixed at 16 and rows at 8.
- `PedalNote.id` is derived from `step-row`.
- Current persisted musical output is replayed rather than regenerated.
- `Pedalboard.id` is a UUID independent of any pedal it references.
- `PedalboardEntry.id` is a UUID created per insertion; the same `PedalboardEntry.pedalID` may appear in multiple entries.
- `Pedalboard.updatedAt` is refreshed by structural and naming mutations only; playback does not touch it.
- Pedalboards are persisted in `Application Support/pedalboards/<uuid>.json` using the `PedalboardDocument` envelope with `schemaVersion == 1`; unknown schemas produce a recoverable issue and the file is preserved untouched.
- There is no `MusicRecipe` type, generator version, migration system, gallery, playback coordinator, or board UI model yet.
- `generatorVersion` is planned, not implemented. Its ownership and compatibility contract require a separate approved specification.
