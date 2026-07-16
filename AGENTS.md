# Agent Instructions

## Project Summary

Photo Pedal is an iOS app that turns a photo into a 2-bit cover, deterministic musical sequence, playable synth sound, effect configuration, and generated metadata. The current core flow is capture/import, processing, playback, and saving the latest pedal.

## Sources Of Truth

Implementation is the source of truth for what currently exists. Report code/documentation mismatches before relying on documentation.

When documents conflict, use this precedence:

1. An active specification in `specs/current/`
2. Accepted ADRs in `docs/decisions/`
3. Architecture and domain contracts in `docs/`
4. `docs/PRODUCT_SPEC.md`
5. `docs/ROADMAP.md`
6. `README.md` summaries

## Non-Negotiable Invariants

- Equivalent normalized image pixels must produce the same musical sequence under the same algorithm. This is implemented but lacks end-to-end regression coverage.
- Persisted generated notes and sound settings must be played from storage rather than silently recalculated. Current storage covers only the latest pedal; no generator version exists yet.
- Foundation Models metadata must not control the deterministic sequence, harmony, or sound profile.
- Keep deterministic domain logic independently testable.
- Keep audio graph creation and rendering outside SwiftUI views.
- Persistent domain data must not be owned only by temporary view state.
- Do not add third-party dependencies without explicit justification and approval.
- Preserve accessibility behavior and Reduce Motion behavior where they exist; add equivalent support when introducing motion.
- Do not implement roadmap work without an active specification.

## Before Editing

1. Read the active feature specification, if one applies.
2. Read related architecture and domain documents.
3. Inspect the implementation and tests.
4. Report code/documentation conflicts.
5. Identify affected invariants.
6. Prefer localized changes over rewrites.

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
