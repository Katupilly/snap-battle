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

`PhotoPedal` remains `Codable` with its existing schema, plus the optional metadata field `generatorVersion: Int?` introduced in Increment 2 of the photo-to-MIDI v2 evolution (`specs/current/photo-midi-variety-v2-incremento-2.md`). `PedalStore` serializes the complete final note events and sound settings to `<PhotoPedal.id>.json` and stores the processed cover as `<PhotoPedal.id>.png`; collection lookup derives that path from identity rather than `coverFilename`. The legacy `latest-pedal.json`/`latest-pedal.png` pair remains readable and is preserved after idempotent migration. The original image, input fingerprint, color analysis, Vision data, board data, and image file URLs are not persisted.

`PedalSequence` decodes missing `soundProfile` as `PedalSoundProfile.legacy`; this is the only current decode compatibility behavior.

### `PhotoPedal.generatorVersion`

The `generatorVersion` field records the algorithm version that produced the persisted sequence. The contract (`specs/current/photo-midi-variety-v2.md` §13.2, Increment 2 §6.6) is:

- **Decode**: missing or `null` decodes as `nil`; explicit integers (including unknown values such as `3`, `99`, `-1`) are preserved verbatim. Runtime code that consumes `PhotoPedal` treats `nil` as the legacy v1 algorithm.
- **Encode**: `nil` is omitted from the JSON; non-nil values are written as `"generatorVersion": N`. Recoding a legacy pedal therefore produces a JSON without the field.
- **Production**: new pedals written by Increment 2+ persist `generatorVersion = 1` (the active algorithm is still v1; `2` lands in Increment 3).
- **Helpers**: `updatingMetadata(name:description:)` and `updating(effect:soundProfile:)` preserve the existing `generatorVersion` value, including `nil`.
- **Migration**: there is no in-place migration. Pedals loaded from disk are replayed literally per ADR 0002; the `generatorVersion` is metadata, not a regeneration trigger.
- **PedalStore**: `validateMetadataUpdateTemporaryJSON` continues to compare only `id`, `createdAt`, `sequence`, `effect`, and `coverFilename`. The `generatorVersion` is read-only on metadata updates, so the existing validator is sufficient.

## Storage Scope

- **Ephemeral session state:** `PhotoPedalViewModel` holds the currently displayed pedal, cover, selected effect, and synth playback state while the app runs.
- **Collection storage:** `PedalStore` loads, validates, orders, saves, deletes, and migrates local pedal pairs.
- **Pedalboard storage:** `PedalboardStore` loads, validates, orders, saves, and deletes pedalboard documents in `Application Support/pedalboards/`. It only references pedals by `StoredPedal.ID` and never reads, writes, or deletes `PedalStore` records.
- **Gallery:** presents valid persisted pedals; invalid pairs are excluded without blocking valid records.
- **Cache, export, and sharing:** not implemented. Pedalboard playback is transient runtime coordination and does not add persisted fields.

## Invariants And Gaps

- Steps are fixed at 16 and rows at 8.
- `PedalNote.id` is derived from `step-row`.
- Current persisted musical output is replayed rather than regenerated.
- `generatorVersion` is now persisted on new pedals (`1` for Increment 2; the field is `nil` for pre-Increment-2 pedals and treated as `1` at runtime). The persisted sequence is still replayed literally per ADR 0002; the version is metadata, not a regeneration trigger.
- `Pedalboard.id` is a UUID independent of any pedal it references.
- `PedalboardEntry.id` is a UUID created per insertion; the same `PedalboardEntry.pedalID` may appear in multiple entries.
- `Pedalboard.updatedAt` is refreshed by structural and naming mutations only; playback does not touch it.
- Pedalboards are persisted in `Application Support/pedalboards/<uuid>.json` using the `PedalboardDocument` envelope with `schemaVersion == 1`; unknown schemas produce a recoverable issue and the file is preserved untouched.
- There is no `MusicRecipe` type, migration system, gallery, or board UI model yet.
- The v2 photo-to-MIDI types (`VisualAnalysis`, `VisualAnalyzer`, `MusicalProfile`, `MelodicContour`, `TonalFamily`) are introduced as in-memory types in Increment 2 of `specs/current/photo-midi-variety-v2.md`. They are not persisted. The v2 music-generation algorithm that consumes them is not implemented in this increment.
