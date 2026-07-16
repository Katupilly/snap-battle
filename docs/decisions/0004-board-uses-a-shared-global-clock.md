# 0004 — Board Uses A Shared Global Clock

Status: Proposed
Date: 2026-07-16

## Context

The roadmap proposes boards that order pedals without becoming timeline editors.

## Decision

If boards are implemented, they should use one global timing source and quantized pedal transitions.

## Consequences

### Positive

- Keeps the board interaction simple and predictable.

### Negative

- Requires a dedicated board playback design.

## Alternatives Considered

- Independent timing per pedal.

## References

- [Roadmap](../ROADMAP.md)
