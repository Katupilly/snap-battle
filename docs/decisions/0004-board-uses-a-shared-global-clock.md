# 0004 — Board Uses A Shared Global Clock

Status: Proposed
Date: 2026-07-16

## Context

The planned Board feature may order pedals without becoming a timeline editor. No Board model or Board playback exists in the current MVP.

## Decision

For the future Board feature only, evaluate one global timing source and quantized pedal transitions. This proposal does not establish a rule for the current MVP.

## Consequences

### Positive

- Keeps the board interaction simple and predictable.

### Negative

- Requires a dedicated board playback design.

## Alternatives Considered

- Independent timing per pedal.

## References

- [Individual Board draft](../../specs/planned/individual-board.md)
