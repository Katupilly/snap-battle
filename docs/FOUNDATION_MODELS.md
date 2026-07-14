# Foundation Models

## Index

- [Purpose](#purpose)
- [Current Usage](#current-usage)
- [Model Responsibilities](#model-responsibilities)
- [Non-Model Responsibilities](#non-model-responsibilities)
- [Availability and Failure Handling](#availability-and-failure-handling)
- [Limitations](#limitations)
- [Future Improvements](#future-improvements)
- [Open Questions](#open-questions)

## Purpose

This document defines how Snap Battle uses Apple Foundation Models and where the model is intentionally not responsible for gameplay rules.

## Current Usage

Status: Implemented in the PoC.

Foundation Models creates a structured `CreatureDraft` from `ObjectObservation.promptRepresentation`.

The prompt includes:

- Normalized Vision labels.
- Top label confidence.
- Optional subject confidence.
- Aspect ratio.
- Inferred material.
- Material confidence.

The model is instructed to:

- Create a concise creature concept.
- Use only supplied structured metadata.
- Avoid physical claims such as real material, weight, or size.
- Avoid numeric game attributes, combat values, balance, or stats.
- Choose exactly one role from `guardian`, `striker`, `trickster`, or `channeler`.
- Return only structured fields.
- Keep content family-friendly.

## Model Responsibilities

| Responsibility | Status |
| --- | --- |
| Creature name | Creative |
| Role choice | Creative constrained |
| Temperament | Creative |
| One-sentence description | Creative |
| Visual tags | Creative |

## Non-Model Responsibilities

| Responsibility | Owner | Reason |
| --- | --- | --- |
| Image preparation | App | Must be deterministic and testable. |
| Vision labels | Vision | Uses platform image analysis. |
| Material inference | App heuristic | Keeps rule visible and editable. |
| Validation | App | Protects app state from invalid model output. |
| Stats | Game rules | Balance must be deterministic and testable. |
| Combat values | Game rules | Avoids model-driven balance drift. |

## Availability and Failure Handling

The app checks `SystemLanguageModel.default.availability`.

Current unavailable states include:

- Device not eligible.
- Apple Intelligence not enabled.
- Model not ready.
- Unsupported locale.
- Other system-reported availability reasons.

Generation failures are wrapped as app errors, including model refusal and general Foundation Models failure.

## Limitations

- The model currently does not inspect image pixels directly.
- Output can vary, so creative identity is not guaranteed deterministic.
- Locale and device support affect availability.
- The model may refuse or fail for system reasons.
- The model should not be trusted for gameplay balance.

## Future Improvements

Status: Exploration.

| Area | Direction |
| --- | --- |
| Prompt engineering | Improve consistency, novelty, and role distribution. |
| Structured outputs | Expand or version the generated schema. |
| Image understanding | Revisit direct image understanding if platform support and product goals fit. |
| Caching | Cache generations by fingerprint and prompt version. |
| Evaluation | Build a sample set for quality, safety, and consistency checks. |
| Prompt versions | Track prompt changes as technical and design decisions. |
| Fallbacks | Improve behavior when the model is unavailable. |

## Open Questions

- Should generation be cached by image fingerprint?
- Should the player be able to reroll identity?
- Should prompt versions be stored with generated creatures?
- Should role distribution be controlled outside the model?
- What quality bar makes a generated creature collection-worthy?
