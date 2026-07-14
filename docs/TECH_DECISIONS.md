# Technical Decisions

## Index

- [Purpose](#purpose)
- [Decision Log](#decision-log)
- [Current Architecture Notes](#current-architecture-notes)
- [Open Questions](#open-questions)

## Purpose

This document records technical decisions that should guide future implementation. Every major feature should update this log when it changes architecture, dependencies, platform assumptions, or data ownership.

## Decision Log

| Date | Decision | Motivation | Impact | Status |
| --- | --- | --- | --- | --- |
| 2026-07-14 | Use SwiftUI for the app UI. | Fast native iteration and modern Apple platform alignment. | UI is organized around SwiftUI views with UIKit interop only where needed. | Decided |
| 2026-07-14 | Use Vision and VisionKit for on-device image understanding. | Keep the PoC Apple-native and avoid external image services. | Subject extraction and image labels depend on device/platform capabilities. | Decided |
| 2026-07-14 | Use Apple Foundation Models for creature identity. | Generate creative structured content on device. | Generation depends on Apple Intelligence availability, locale, and model readiness. | Decided |
| 2026-07-14 | Do not use external AI services. | Preserve privacy direction and reduce backend complexity. | Current AI flow is on-device only. | Decided |
| 2026-07-14 | Do not use a backend in the PoC. | Keep the prototype local and focused on the generation loop. | No account, sync, multiplayer, or server persistence yet. | Decided for PoC |
| 2026-07-14 | Keep stats deterministic and outside Foundation Models. | Balance must be reproducible, testable, and designer-controlled. | Foundation Models cannot set numeric attributes. | Decided |
| 2026-07-14 | Validate model output before building a creature. | Protect app state from empty, invalid, or oversized generated content. | Invalid drafts fail with `AppError.invalidDraft`. | Decided |
| 2026-07-14 | Use a pipeline service to orchestrate generation. | Keep image prep, Vision, generation, validation, and stats in one traceable flow. | Diagnostics can report stage progress and failures. | Decided |
| 2026-07-14 | Use stable image fingerprinting. | Support future caching, reproducibility, diagnostics, and comparison. | The current fingerprint is deterministic but not yet a gameplay rule. | Implemented |
| 2026-07-14 | Use Swift Testing for core pipeline and rules tests. | Cover deterministic behavior and important failure paths. | Current tests focus on stats, image fingerprints, cancellation, and model errors. | Decided |

## Current Architecture Notes

| Area | Current Shape |
| --- | --- |
| Data models | Value types in `Domain`, including `Creature`, `CreatureDraft`, `ObjectObservation`, and `CreatureStats`. |
| UI | SwiftUI views grouped by feature. |
| Services | Separate services for image prep, Vision, Foundation Models, game rules, and pipeline orchestration. |
| Concurrency | Async pipeline with cancellation checks between major stages. |
| Diagnostics | Stage durations, failure stage, observation, draft, stats, model availability, and image metadata. |
| Privacy | Current design does not require external servers. |

## Open Questions

- When should local persistence be introduced?
- Should generated creatures store raw image data, extracted subject data, or only a rendered card?
- Should prompt versions become part of the persisted model?
- Should the app introduce dependency injection beyond the current service initializer pattern?
- How should future multiplayer change the no-backend assumption?
- What data should sync through iCloud, if any?
