# 0003 — Foundation Models For Semantic Metadata

Status: Accepted
Date: 2026-07-16

## Context

The product needs short human-readable names and descriptions without making AI part of sound generation.

## Decision

Use Apple Foundation Models to generate and validate `PedalDraft` metadata only.

## Consequences

### Positive

- Musical output remains deterministic.

### Negative

- Current creation fails when the model is unavailable or output is invalid.

## Alternatives Considered

- Deterministic metadata only.

## References

- [Foundation Models integration](../FOUNDATION_MODELS.md)
