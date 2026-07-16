# Foundation Models Integration

## Role

`FoundationModelsPedalGenerator` creates only a `PedalDraft`: a concise name and one-sentence description. It must not control the sequence, harmony, sound profile, or effect calculation.

## Current Flow

`PhotoPedalPipeline` asks `SubjectExtractionService` for a foreground subject when available, then `VisionObjectAnalyzer` classifies an image and retains up to five labels. These results provide context to `FoundationModelsPedalGenerator`. The generated `PedalDraft` is validated by `PedalDraftValidator`: name must be nonempty and at most 24 characters; description must be nonempty and at most 140 characters.

The prompt instructs the model not to use creature, stats, combat, or game mechanics terminology. Vision labels currently pass through legacy `CreatureMaterial` mapping; this is pivot debt, not product vocabulary.

## Availability And Failure

The generator requires `SystemLanguageModel.default.availability == .available` and current-locale support. Unavailable, refused, or invalid output fails the current creation flow; there is no fallback name/description, timeout policy, or retry policy.

The integration uses Apple on-device Foundation Models APIs. This repository does not establish a broader privacy claim beyond that local API choice. There are no mocks or focused tests for the pedal metadata generator.
