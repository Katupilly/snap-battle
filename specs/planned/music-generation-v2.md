# Music Generation V2

Status: Draft
Last updated: 2026-07-16

> This specification is not authorized for implementation.
> Product and technical decisions listed under Open Questions must be resolved first.

## Goal

Increase perceptible musical variety while preserving deterministic, locally generated musical output.

## User Value

Different image categories should produce recognizably different but usable results without music-theory controls.

## Confirmed Current Behavior

The current 16 by 8 generator uses four scales and persists final notes for the latest pedal only. It has no `generatorVersion`, hash-based micro-variation, fixture-based sequence regression suite, or polyphony constraint. See [Image-to-music generation](../../docs/IMAGE_TO_MUSIC.md) and [ADR 0001](../../docs/decisions/0001-deterministic-local-music-generation.md).

## User Stories

- As a user, I hear meaningfully different results from visually different photos.
- As a returning user, an already saved pedal sounds as it did when it was created.

## Proposed Changes

- Consider a persisted generator version.
- Consider additional harmonic profiles from the roadmap's suggested list.
- Consider deterministic feature mappings and micro-variations only after defining an input contract.
- Keep Foundation Models out of musical generation.
- Define a compatibility approach for already persisted latest-pedal output.
- Define fixture-based deterministic regression coverage.

## Non-Goals

- User-facing scale selection, advanced theory controls, and manual note editing.
- Gallery, Board, sharing, collaboration, or video export.
- Audio-engine replacement.
- Complete persistence beyond the latest pedal.
- Foundation Models generation of notes or rhythm.

## Candidate Acceptance Criteria

- Equivalent normalized inputs reproduce the same agreed sequence under the finalized algorithm.
- Compatibility behavior for existing latest-pedal data is explicitly tested after a design is chosen.
- Fixtures cover finalized mappings and agreed edge cases.
- Perceived musical variety and usability require perceptual validation; unit tests alone cannot prove them.

## Open Product Decisions

- Which perceptible differences matter to users, and how should musical variety be evaluated?
- Which suggested harmonic profiles belong to the product identity?
- What safety rules define usable dense output?

## Open Technical Decisions

- Whether generator versioning is needed before a gallery exists, and the smallest compatible contract if it is.
- Whether any stable input identity is needed; the current fingerprint has no approved responsibility.
- Final feature mappings, micro-variation design, fixtures, and latest-pedal compatibility behavior.
- Whether proposed changes require audio-renderer changes or only generation changes.
