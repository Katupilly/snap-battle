# Music Generation V2

Status: Active
Last updated: 2026-07-16

## Goal

Increase perceptible musical variety while preserving deterministic, locally generated musical output.

## User Value

Different image categories should produce recognizably different but usable results without music-theory controls.

## Current Context

The current 16 by 8 generator uses four scales and persists final notes, but does not store a generator version or constrain dense polyphony. See [Image-to-music generation](../../docs/IMAGE_TO_MUSIC.md) and [ADR 0001](../../docs/decisions/0001-deterministic-local-music-generation.md).

## User Stories

- As a user, I hear meaningfully different results from visually different photos.
- As a returning user, an already saved pedal sounds as it did when it was created.

## Functional Requirements

- Add a persisted generator version.
- Add curated harmonic profiles approved by the roadmap.
- Define deterministic feature mappings and hash-based micro-variations.
- Keep Foundation Models out of musical generation.
- Preserve playback of already persisted results without recalculation.
- Add fixture-based deterministic regression tests.

## Interaction States

No advanced music-theory controls are introduced. Existing processing and result states remain the user-facing flow.

## Data Model Changes

Add a persisted generator version and any versioned recipe data required to replay saved output without recalculation.

## Architecture Impact

Changes are limited to deterministic domain/pipeline logic, persistence compatibility, and tests. Audio rendering and Foundation Models metadata boundaries remain unchanged.

## Accessibility

Do not add new controls. Existing accessible result presentation must remain intact.

## Error Handling

Invalid images and unsupported persisted data must surface existing app errors or an explicitly designed compatibility state; do not silently replace stored output.

## Non-Goals

- User-facing scale selection, advanced theory controls, manual note editing, boards, or new effects.

## Acceptance Criteria

- Equivalent normalized inputs reproduce the same V2 sequence.
- Existing stored output remains unchanged.
- Fixtures cover variety and edge cases.
- Dense output remains musically usable under agreed safety rules.

## Required Tests

- Unit tests for mappings, version handling, and fixtures.
- Persistence compatibility tests.

## Device Validation

- Manual listening across a varied image set.

## Documentation Updates

- Update image-to-music, data-model, testing, and relevant ADR documentation when the compatibility design is accepted.

## Open Questions

- Final harmonic-profile mapping and compatibility policy for legacy latest-pedal data.
