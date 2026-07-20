# Foundation Models Integration

## Role

`FoundationModelsPedalGenerator` creates only a `PedalDraft`: a concise name and one-sentence description. It must not control the sequence, harmony, sound profile, or effect calculation.

## Current Flow

The essential creation path prepares the image, creates the cover, analyzes color, generates the deterministic sequence, creates a `PhotoPedal` with fallback metadata, persists it, and presents the playable result. Semantic enrichment then asks `SubjectExtractionService` for a foreground subject when available, asks `VisionObjectAnalyzer` to classify the image and retain up to five labels, and passes that context to `FoundationModelsPedalGenerator`. The generated `PedalDraft` is validated by `PedalDraftValidator`: name must be nonempty and at most 24 characters; description must be nonempty and at most 140 characters.

The prompt instructs the model not to use creature, stats, combat, or game mechanics terminology. Vision labels currently pass through legacy `CreatureMaterial` mapping; this is pivot debt, not product vocabulary.

## Availability, Failure, And Fallback

The generator requires `SystemLanguageModel.default.availability == .available` and current-locale support for model-generated metadata. Unavailable, refused, failed, empty, invalid, stale, cancelled, or unpersistable metadata output does not abort creation because the musical result is already saved with fallback metadata:

- name: `Dap`
- description: `A photo-generated sound pedal.`

Image preparation, cover generation, color analysis, initial persistence, and musical sequence generation failures still abort the essential flow. The fallback is only for semantic metadata and does not change the musical sequence, fingerprint, persistence schema, filenames, cover, or audio lifecycle. Successful enrichment updates only `name` and `description` for the existing `PhotoPedal.id`.

The integration uses Apple on-device Foundation Models APIs. This repository does not establish a broader privacy claim beyond that local API choice. Tests use the `PedalMetadataGenerating` seam for metadata success and fallback paths without depending on live Foundation Models. Live Foundation Models availability, locale behavior, and device prompts remain physical-device validation items. There is no timeout policy or retry policy.
