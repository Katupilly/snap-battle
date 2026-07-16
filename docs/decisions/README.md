# Architecture Decisions

An Architecture Decision Record (ADR) captures a durable, consequential choice. Create one when a change establishes a cross-feature rule, persistence contract, platform integration boundary, or difficult-to-reverse direction. Do not create ADRs for minor implementation details.

Use `NNNN-short-decision-name.md`. Statuses are Proposed, Accepted, Superseded, and Rejected. Accepted ADRs must not be silently rewritten; supersede them with a new ADR when needed.

```md
# NNNN — Decision Title

Status: Proposed | Accepted | Superseded | Rejected
Date: YYYY-MM-DD

## Context

## Decision

## Consequences

### Positive

### Negative

## Alternatives Considered

## References
```

## Accepted Decisions

- [0001 Deterministic local music generation](0001-deterministic-local-music-generation.md)
- [0002 Persist generated musical results](0002-persist-generated-musical-results.md)
- [0003 Foundation Models for semantic metadata](0003-foundation-models-for-semantic-metadata.md)

## Proposed Decisions

Proposed ADRs do not authorize implementation and may change or be rejected.

- [0004 Board uses a shared global clock](0004-board-uses-a-shared-global-clock.md)
