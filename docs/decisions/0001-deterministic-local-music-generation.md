# 0001 — Deterministic Local Music Generation

Status: Accepted
Date: 2026-07-16

## Context

Photo Pedal must turn equivalent prepared image pixels into repeatable musical output without network generation or Foundation Models control.

## Decision

Generate `PedalSequence` and `PedalSoundProfile` locally from prepared-image analysis and the retro cover. Keep Foundation Models outside the musical calculation.

## Consequences

### Positive

- Core playback remains independently testable.
- Vision and Foundation Models availability do not alter notes.

### Negative

- Current variation is limited and needs versioned evolution.

## Alternatives Considered

- Model-generated note sequences.

## References

- [Image-to-music generation](../IMAGE_TO_MUSIC.md)
