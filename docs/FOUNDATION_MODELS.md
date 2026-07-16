# Foundation Models Integration

## Role

`FoundationModelsPedalGenerator` creates only a `PedalDraft`: a concise name and one-sentence description. It must not control the sequence, harmony, sound profile, or effect calculation.

## Current Flow

`PhotoPedalPipeline` asks `SubjectExtractionService` for a foreground subject when available, then `VisionObjectAnalyzer` classifies an image and retains up to five labels. These results provide context to `FoundationModelsPedalGenerator`. The generated `PedalDraft` is validated by `PedalDraftValidator`: name must be nonempty and at most 24 characters; description must be nonempty and at most 140 characters.

The prompt instructs the model not to use creature, stats, combat, or game mechanics terminology. Vision labels currently pass through legacy `CreatureMaterial` mapping; this is pivot debt, not product vocabulary.

## Availability, Failure, And Fallback

The generator requires `SystemLanguageModel.default.availability == .available` and current-locale support for model-generated metadata. Unavailable, refused, failed, empty, or invalid metadata output no longer aborts creation after the musical result exists. The pipeline uses this fallback metadata instead:

- name: `Photo Pedal`
- description: `A photo-generated sound pedal.`

Image preparation, cover generation, color analysis, and musical sequence generation failures still abort the pipeline. The fallback is only for semantic metadata and does not change the musical sequence, fingerprint, persistence schema, filenames, or audio lifecycle.

The integration uses Apple on-device Foundation Models APIs. This repository does not establish a broader privacy claim beyond that local API choice. Tests use the `PedalMetadataGenerating` seam for metadata success and fallback paths without depending on live Foundation Models. Live Foundation Models availability, locale behavior, and device prompts remain physical-device validation items. There is no timeout policy or retry policy.
