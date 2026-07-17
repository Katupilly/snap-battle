# 0002 — Persist Generated Musical Results

Status: Accepted
Date: 2026-07-16

## Context

Replaying a saved pedal must not depend on recalculating its notes.

## Decision

Persist the final `PhotoPedal` sequence and sound profile with its processed cover. The current implementation stores UUID-associated JSON/PNG collection records and preserves the legacy `latest-pedal.json`/`latest-pedal.png` pair only as a reversible migration fallback.

## Consequences

### Positive

- The saved latest pedal replays its original generated notes.

### Negative

- There is no generator version yet.

## Alternatives Considered

- Persist source input and regenerate on every load.

## References

- [Data model](../DATA_MODEL.md)
