# Agent Instructions

## Project Summary

Photo Pedal is an iOS app that turns a photo into a 2-bit cover, deterministic musical sequence, playable synth sound, effect configuration, and generated metadata. The current core flow is capture/import, processing, playback, and saving the latest pedal.

## Sources Of Truth

Implementation is the source of truth for what currently exists. Report code/documentation mismatches before relying on documentation.

When documents conflict, use this precedence:

1. A specification in `specs/current/` with status `Ready` or `In Progress`
2. Accepted ADRs in `docs/decisions/`
3. Architecture and domain contracts in `docs/`
4. `docs/PRODUCT_SPEC.md`
5. `docs/ROADMAP.md`
6. Specifications in `specs/planned/`
7. Legacy documents
8. `README.md` summaries

If sources conflict, stop implementation and record the divergence. Do not silently select an interpretation.

Agents may only implement a specification located in `specs/current/` with status `Ready` or `In Progress`.

Documents and ADRs marked `Proposed`, `Draft`, or `Planned` are not implementation authorization.

## Non-Negotiable Invariants

- Equivalent normalized image pixels must produce the same musical sequence under the same algorithm. This is implemented but lacks end-to-end regression coverage.
- Persisted generated notes and sound settings must be played from storage rather than silently recalculated. Current storage covers only the latest pedal; no generator version exists yet.
- Foundation Models metadata must not control the deterministic sequence, harmony, or sound profile.
- Keep deterministic domain logic independently testable.
- Keep audio graph creation and rendering outside SwiftUI views.
- Persistent domain data must not be owned only by temporary view state.
- Do not add third-party dependencies without explicit justification and approval.
- Preserve accessibility behavior and Reduce Motion behavior where they exist; add equivalent support when introducing motion.
- Do not implement roadmap work without a `Ready` or `In Progress` specification in `specs/current/`.

## Before Editing

1. Read the active feature specification, if one applies.
2. Read related architecture and domain documents.
3. Inspect the implementation and tests.
4. Report code/documentation conflicts.
5. Identify affected invariants.
6. Prefer localized changes over rewrites.

## Skill Routing

Skills are execution tools, not product sources of truth. `AGENTS.md`, current specs, ADRs, and repository architecture documentation keep precedence for Photo Pedal decisions.

Before using a skill, confirm it is available in the session. Use only the skills relevant to the current task, and do not copy global skills into the repository. For cross-domain tasks, combine skills only when each has a clear responsibility. Do not silently combine conflicting guidance; follow repository-specific documentation and record the divergence.

- `swiftui-ui-patterns`: creating new screens, SwiftUI components, navigation, layout composition, UI states, and controls.
- `swiftui-view-refactor`: splitting large views, reorganizing state ownership, improving data flow, or reducing structural coupling.
- `swiftui-performance-audit`: excessive rendering, scrolling jank, expensive updates, or suspected SwiftUI performance problems.
- `ios-ettrace-performance`: only when runtime profiling evidence is needed.
- `ios-memgraph-leaks`: suspected leaks, persistent memory growth, or retain cycles.
- `ios-app-intents`: creating or modifying App Intents, App Entities, App Shortcuts, Siri, Spotlight, widgets, or controls.
- `ios-debugger-agent`: building, running, and debugging the app in Simulator, inspecting logs, or reproducing runtime issues.
- `ios-simulator-browser`: when visual inspection or direct Simulator UI interaction provides relevant evidence.
- `swiftui-liquid-glass`: implementing, reviewing, or correcting interfaces that use Liquid Glass on iOS 26+.
- `photokit`: modifying photo import, authorization, loading, metadata, or Photos library access.
- `vision-framework`: modifying image processing, visual analysis, or Vision APIs.
- `foundation-models-on-device`: modifying on-device generation, schemas, sessions, prompts, availability, or Foundation Models fallbacks.

## Scope Control

Do not implement unrelated roadmap work. Current non-goals include manual piano-roll editing, multitrack DAW behavior, cloud sync, effects outside approved scope, automatic social publishing, and speculative collaboration abstractions.

## Validation

- Domain changes: run focused deterministic and serialization tests.
- Audio changes: run available tests and complete relevant device checks.
- Persistence changes: test save, reload, decode compatibility, and relaunch behavior.
- UI changes: build and check accessibility, motion, empty, and error states as applicable.
- App Intents changes: validate the intent's app-launch and routing behavior on device.
- Documentation-only changes: validate links, paths, type references, and `git diff --check`.

Always report validation not run.

## Completion Report

Every implementation report must state: summary, files changed, behavior changed, architectural decisions, tests run, tests not run, remaining risks, outdated documentation, and scope intentionally left unchanged.
