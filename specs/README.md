# Feature Specifications

Roadmap entries are direction, not implementation authorization. Significant work needs a specification before implementation.

- `planned/` contains `Draft` specifications with unresolved decisions. They are not authorized for implementation.
- `current/` contains only `Ready` or `In Progress` specifications approved for implementation.
- Completed specifications may be archived later or retain a `Done` status until an archive location is established.

## Statuses

- **Draft:** contains open product or technical decisions.
- **Ready:** scope, acceptance criteria, and essential decisions are resolved; implementation is authorized.
- **In Progress:** implementation is authorized and has started.
- **Done:** implementation, validation, and documentation are complete.

Specification location follows status: use `planned/` for Draft, `current/` for Ready or In Progress, and an appropriate historical location or internal Done status after completion.

Each specification must reference relevant ADRs and documentation, identify data and architecture effects, define validation, and use this template:

```md
# Feature Name

Status: Draft | Ready | In Progress | Done | Superseded
Last updated: YYYY-MM-DD

## Goal
## User Value
## Current Context
## User Stories
## Functional Requirements
## Interaction States
## Data Model Changes
## Architecture Impact
## Accessibility
## Error Handling
## Non-Goals
## Acceptance Criteria
## Required Tests
## Device Validation
## Documentation Updates
## Open Questions
```

A Ready or In Progress specification in `current/` authorizes only its stated scope.

## Current Specifications

- [Photo Pedal Vertical Slice Stabilization](current/vertical-slice-stabilization.md) (`Ready`)
- [Navigation and Gallery Foundation](current/navigation-gallery-foundation.md) (`Ready`)
- [Contextual Bottom Bar Morph](current/contextual-bottom-bar.md) (`Ready`)
- [Photo Pedal Library](current/pedal-library.md) (`Ready`)
