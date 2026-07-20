# Spec: Dap Vertical Slice Stabilization

Status: Ready
Priority: P0

## Context

The current Dap vertical slice captures or imports a photo, prepares it, produces a four-tone cover, generates a deterministic `PedalSequence`, generates semantic metadata or static fallback metadata, plays it through `PhotoPedalSynth`, and persists the latest result. The product flow is active. The `snap-battleTests` target currently has 62 tests in 6 suites, including focused Dap coverage for deterministic generation, metadata fallback, latest-pedal persistence, audio lifecycle coordination, and App Intent routing where testable without device/framework invocation.

This specification stabilizes existing behavior. It does not authorize creative changes to the image-to-music algorithm or product expansion.

References:

- [Architecture](../../docs/ARCHITECTURE.md)
- [Image-to-music generation](../../docs/IMAGE_TO_MUSIC.md)
- [Audio system](../../docs/AUDIO_SYSTEM.md)
- [Foundation Models integration](../../docs/FOUNDATION_MODELS.md)
- [Testing](../../docs/TESTING.md)
- [ADR 0001](../../docs/decisions/0001-deterministic-local-music-generation.md)
- [ADR 0002](../../docs/decisions/0002-persist-generated-musical-results.md)
- [ADR 0003](../../docs/decisions/0003-foundation-models-for-semantic-metadata.md)

## Problem

Current boundaries and remaining validation:

- `PhotoPedalPipeline.run(image:stage:)` now falls back to static metadata when semantic metadata generation is unavailable, refused, failed, empty, or invalid after the musical result exists. Image preparation, cover processing, color analysis, and sequence-generation failures still interrupt the pipeline.
- `PedalStore` saves and loads only the latest pedal; save, reload, replacement, and incomplete-storage behavior have focused tests.
- `PhotoPedalSynth.play(_:)` stops an existing playback before starting another. Focused tests cover clean stop state; route-change recovery, automatic interruption recovery, and a playback-concurrency policy are not implemented.

Potential risks requiring proportional validation, not assumed defects:

- Camera, VisionKit, Foundation Models availability, output routes, interruptions, and audible playback depend on physical-device runtime conditions.
- `PhotoPedalViewModel.play()` currently ignores a thrown playback error; a demonstrated failure must leave the view-model state usable and must not alter the stored pedal.

## Objective

Make the current vertical slice verifiable, reproducible in the applicable domain, and resilient to runtime failures without changing its intentional creative output.

## User Outcome

Users can complete the existing photo-to-pedal flow when semantic metadata services are unavailable, replay the latest stored pedal, and start another playback without overlapping playback from the same synth instance. The generated musical result remains unchanged for the same normalized input and current algorithm.

## Confirmed Current Behavior

- `ImageInputPreparer.prepare(_:)` in `snap-battle/Services/ImageInputPreparer.swift` normalizes orientation and returns a `PreparedImage`; its SHA-256 fingerprint uses a 32 by 32 sRGB rendering but is not consumed by music generation or persistence.
- `RetroImageProcessor.process(_:)` in `snap-battle/Services/ImageProcessing/RetroImageProcessor.swift` produces an aspect-preserving, 160-pixel-wide four-tone image.
- `PhotoColorAnalyzer.analyze(_:)` in `snap-battle/Services/Pedal/PhotoColorAnalyzer.swift` produces hue, saturation, luminance, hue variance, and edge density.
- `ImageSequenceGenerator.makeSequence(retroImage:colorProfile:)` in `snap-battle/Services/Pedal/ImageSequenceGenerator.swift` creates a 16-step by 8-row `PedalSequence`. Grid `level == 0` emits no event (a rest); levels `1...3` emit `PedalNote` events with velocity `level / 3`.
- `PhotoPedalPipeline.run(image:stage:)` in `snap-battle/Services/Pedal/PhotoPedalPipeline.swift` prepares the image, creates the cover and sequence, runs subject extraction and visual analysis, obtains and validates a `PedalDraft` through `PedalMetadataGenerating`, then creates `PhotoPedal` with a new UUID and creation date. If semantic metadata fails after the musical result exists, it uses fallback name `Photo Pedal` and description `A photo-generated sound pedal.`.
- `FoundationModelsPedalGenerator.generate(observation:harmony:)` in `snap-battle/Services/FoundationModels/FoundationModelsPedalGenerator.swift` requires available Foundation Models and locale support for model-generated metadata. `PedalDraftValidator.validate(_:)` rejects empty or over-limit metadata. Pipeline fallback handles unavailable, refused, failed, empty, or invalid metadata output without changing the musical result.
- `PhotoPedalSynth.play(_:)` in `snap-battle/Services/Audio/PhotoPedalSynth.swift` calls `stop()`, configures `AVAudioSession` as `.playback` with `.default` mode, activates it, renders the current 16-step sequence to memory, and starts `AVAudioEngine`. `stop()` detaches the source node, clears playback, stops the engine, and clears `isPlaying`. An interruption beginning calls `stop()`.
- `PedalStore.save(_:cover:)` and `PedalStore.loadLatest()` in `snap-battle/Services/Persistence/PedalStore.swift` overwrite/load `latest-pedal.json` and `latest-pedal.png` in Application Support. `loadLatest()` returns `nil` if either component cannot load.
- `PhotoPedalViewModel` in `snap-battle/Features/Capture/CaptureViewModel.swift` blocks duplicate `process(_:)` calls while `isProcessing`, resets that state with `defer`, saves generated results, reloads the latest pedal at initialization, and calls `synth.play(_:)` from `play()`.
- `CreatePedalIntent` and `PlayLastPedalIntent` in `snap-battle/Intents/PhotoPedalIntents.swift` set `AppIntentRouter.shared.request`; `ContentView` in `snap-battle/Features/Capture/CaptureView.swift` handles `.create` by resetting and opening `CameraScreen`, and `.playLast` by calling `PhotoPedalViewModel.playLast()`.
- Current Dap coverage includes deterministic generation, fallback metadata paths through `PedalMetadataGenerating`, storage replacement/reload behavior, selected audio lifecycle coordination, and App Intent routing. Legacy Snap Battle coverage remains present.

## In Scope

- Focused Dap domain regression tests for the current deterministic generation contract.
- Minimal deterministic fixtures that do not use the fingerprint as a contract.
- Metadata fallback for unavailable, refused, failed, empty, or invalid Foundation Models output through the existing `PedalMetadataGenerating` seam.
- Focused tests for latest-pedal storage: save, reload, replacement, and absence.
- App Intent routing tests at the level supported by `AppIntentRouter` and manual validation for framework integration.
- Small, demonstrated lifecycle fixes in `PhotoPedalSynth` or `PhotoPedalViewModel` only when required to meet this specification.
- Preventing conflicting playback from one `PhotoPedalSynth` instance, preserving the existing stop-then-start behavior.
- DEBUG-only diagnostics only when required to verify a failure path that cannot otherwise be observed by tests or device validation.
- Documentation updates caused directly by the implementation.

## Out of Scope

- Any intentional perceptible change to generated music, including `music-generation-v2`, new scales, rhythm changes, note/image mapping changes, calibration, or aesthetic changes to the four-tone cover.
- New fingerprint use as seed, identity, cache key, deduplication key, fixture contract, or product feature.
- `generatorVersion`, complete persistence, data migration, gallery, Board, sharing, collaboration, or export.
- Redesign, broad accessibility redesign, visual snapshots, or animation work unrelated to affected states.
- Legacy cleanup, removal, or broad renaming, including `CreatureMaterial` and reused legacy types.
- Audio-engine replacement, offline rendering, new effects, or new dependencies.
- Foundation Models generation of notes, rhythm, harmony, or sound parameters.
- General refactoring or opportunistic optimization.

## Functional Requirements

### Musical Generation

- The same normalized input exercised through the current preparation, cover, analysis, and sequence path must produce the same essential musical data: `PedalHarmony`, ordered `PedalNote` events, and `PedalSoundProfile`.
- Regression tests must cover rests, notes, event order, MIDI-note range, velocity range, and 16-step/8-row bounds supported by the current implementation.
- UUID, `createdAt`, generated name, generated description, and temporary playback state are excluded from deterministic-generation assertions.
- Tests must not require byte-for-byte realtime audio output.
- The implementation must not alter `ImageSequenceGenerator` feature mappings, supported scales, tone thresholds, retro palette, or output dimensions except to correct a demonstrated defect that violates an existing tested behavior.

### Metadata Fallback

- Sequence and cover creation must complete when subject extraction, Vision metadata-context analysis, Foundation Models availability, Foundation Models generation, or `PedalDraftValidator` fails after the musical result is available.
- The fallback `PedalDraft` must be valid under `PedalDraftValidator`: name `Photo Pedal`; description `A photo-generated sound pedal.`. These static values are metadata only and must not affect the musical result.
- Image preparation, cover processing, color analysis, and sequence-generation failures remain errors; they must not be hidden by metadata fallback.
- No timeout is required by this specification because the current code has no timeout behavior and no timeout defect has been demonstrated.

### Last Pedal

- A successfully created pedal and its processed cover must be saved using the existing latest-pedal storage behavior.
- A stored latest pedal must reload with its persisted sequence, effect, sound profile, and cover.
- Saving a later pedal must replace the prior latest pair; this does not create a collection.
- Missing, unreadable, or incomplete latest-pedal storage must produce the existing controlled `nil` result from `loadLatest()`.

### App Intents

- `CreatePedalIntent` and `PlayLastPedalIntent` must continue routing through `AppIntentRouter`; intents must not duplicate image preparation, music generation, persistence, or audio logic.
- `CreatePedalIntent` continues to open the foreground app and request the existing camera flow; it does not capture or create a pedal autonomously.
- `PlayLastPedalIntent` with no stored/current pedal must complete without a crash or generated replacement pedal. Audible outcome remains manual device validation.

## Reliability Requirements

- `PhotoPedalViewModel.isProcessing` must return to `false` after success, cancellation, or error; its task reference must be cleared.
- A duplicate `process(_:)` call while processing must not start another pipeline task.
- Metadata failure must not discard an already generated cover or sequence.
- A save or playback failure must not mutate the musical result already held in memory.
- Error paths must leave the capture/result flow able to accept a new capture or import.
- Unit tests must not depend on network, live Foundation Models, camera hardware, or audio hardware.

## Audio Lifecycle Requirements

- One `PhotoPedalSynth` instance may have at most one active source/playback buffer. Starting another pedal must retain the current `stop()`-then-start behavior.
- `stop()` must leave the synth without an attached active source, without a retained playback buffer, with the engine stopped, and with `isPlaying == false`.
- If `engine.start()` throws, the synth and `PhotoPedalViewModel` must remain usable for a later playback attempt; implementation changes are permitted only if a focused test or device reproduction demonstrates cleanup is incomplete.
- `AVAudioSession` activation remains owned by `PhotoPedalSynth.play(_:)`, not SwiftUI views.
- Interruption beginning currently calls `stop()`. Automatic recovery and route-change handling are not required implementation work in this spec; validate them manually and record results.
- No pause/resume, seek, loop, board playback, or concurrent multi-synth coordination is introduced.

## Foundation Models and Fallback Requirements

- `FoundationModelsPedalGenerator` remains semantic metadata only. It must not influence `PedalSequence`, `PedalHarmony`, `PedalSoundProfile`, selected effect, cover processing, or storage format.
- The fallback applies to unavailable, refused, failed, empty, or invalid metadata output after music generation succeeds.
- Fallback metadata must pass the existing validator and be persisted as part of the latest `PhotoPedal`.
- Existing local-only Foundation Models integration and current prompt guardrails remain unchanged.

## Last-Pedal Storage Requirements

- Preserve `PedalStore`'s two-file latest-pedal contract: `latest-pedal.json` and `latest-pedal.png`.
- Test the current replacement semantics, not gallery behavior.
- Do not add storage schemas, migration behavior, original-image retention, fingerprint storage, or `generatorVersion`.

## App Intents Requirements

- Test the request values set by `CreatePedalIntent.perform()` and `PlayLastPedalIntent.perform()` where the App Intents framework permits it.
- Validate `ContentView` routing and foreground behavior manually on device.
- Keep `openAppWhenRun = true` and the existing Portuguese shortcut phrases unless a concrete defect in this scope requires correction.

## Testing Requirements

### Pure Deterministic Tests

- Add Dap-focused tests under a new `snap-battleTests/PhotoPedalStabilizationTests.swift` file. Keep legacy tests untouched unless a shared current behavior requires a narrowly scoped correction.
- Use synthetic `UIImage` inputs and explicit `PhotoColorProfile`/domain values. Do not add large photos, binary snapshots, or fingerprint-based expectations.
- Cover identical input producing equal `PedalSequence` values across repeated generation.
- Cover `level == 0` as no `PedalNote` event and levels `1...3` as note events with current velocities.
- Cover scale thresholds already implemented by `ImageSequenceGenerator.scale(for:)`, sequence bounds, note ordering, valid MIDI-note values, BPM range, and sound-profile values already derived by the current generator.
- Retain existing four-tone processor tests as coverage of the unchanged cover contract; do not alter palette/output expectations.

### Service Tests

- Test success and fallback metadata paths with lightweight doubles. `RetroImageProcessing`, `SubjectExtracting`, `ObjectAnalyzing`, and `PedalMetadataGenerating` provide seams for testing without live Foundation Models.
- Test fallback for unavailable/refused/failed metadata errors and invalid/empty `PedalDraft` validation.
- Test `PedalStore` save/reload, replacement, and `loadLatest() == nil` for missing or incomplete storage. Add the smallest test-only storage-location seam only if isolation from Application Support is otherwise not possible.
- Test error propagation for image preparation, cover processing, color analysis, or sequence generation separately from metadata fallback; do not convert those failures into successful pedals.

### Audio Coordination Tests

- Test state/coordination only where technically proportional: stop-before-start behavior, `stop()` state cleanup, and view-model usability after a demonstrated playback failure.
- Do not test waveform bytes, audible output, AVAudioEngine timing, or device routes in unit tests.

### App Intents Tests

- Test `AppIntentRouter.Request` changes when supported by the test target.
- Treat App Intents invocation, app launch, camera presentation, and audible playback as manual framework/device validation.

### Regression Scope

New tests must protect Dap code. This work does not pursue coverage percentage or expand legacy Snap Battle tests.

## Device Validation Requirements

Follow [Device Validation](../../docs/DEVICE_VALIDATION.md). Record each result in the implementation report.

| Scenario | Validation mode |
| --- | --- |
| Camera permission and capture | Manual only |
| Photo-library import | Manual only |
| Foundation Models available metadata | Manual only |
| Foundation Models unavailable/refused/invalid metadata fallback | Partially automatable; manual device confirmation |
| Speaker playback and repeated playback | Manual only |
| Wired/Bluetooth headphones and route change | Manual only |
| Audio interruption | Manual only |
| Background/foreground around playback | Manual only |
| App Intents through Shortcuts/Siri | Partially automatable; manual device confirmation |
| Consecutive pedal creation and replay | Partially automatable; manual device confirmation |
| Relaunch and latest-pedal recovery | Partially automatable; manual device confirmation |

## Accessibility Requirements

- If processing/error presentation changes, preserve an announceable processing state and accessible error text.
- If playback controls change, preserve clear play/stop labels and do not communicate playback state only by color.
- Preserve existing accessibility labels in `PedalResultView`.
- If visual feedback changes, preserve current Reduce Motion behavior; this spec does not authorize broader accessibility redesign.

## Technical Constraints

- Use the current Swift 6 project and current iOS target settings.
- Add no dependencies.
- Keep deterministic domain logic independent of SwiftUI.
- Keep audio graph/session ownership in `PhotoPedalSynth`, outside SwiftUI views.
- Do not introduce new fingerprint use or `generatorVersion`.
- Do not intentionally change musical output or persisted format beyond the minimum correction for a demonstrated defect.
- Prefer localized, reversible changes. Create new abstractions only when a concrete testing or lifecycle seam requires them and existing protocols are insufficient.

## Acceptance Criteria

- [ ] Focused Dap tests protect the current deterministic generation contract.
- [ ] An identical synthetic fixture produces equal essential musical data across repeated runs.
- [ ] Tests exclude UUID, creation date, and generated metadata from deterministic assertions.
- [ ] Tests cover `level == 0` as a rest and levels `1...3` as notes with current velocities.
- [ ] Tests cover the current sequence bounds, event order, BPM range, and supported scale-selection thresholds.
- [ ] Foundation Models unavailable, refused, failed, empty, and invalid paths produce the specified valid fallback after sequence generation succeeds.
- [ ] Image, cover, color-analysis, and sequence-generation failures remain controlled errors rather than metadata fallbacks.
- [ ] The latest pedal can be saved, reloaded, and replaced; absent/incomplete latest storage returns the documented controlled absence result.
- [ ] Playback lifecycle covered by this spec has focused tests where feasible and explicit device validation where hardware/framework behavior is involved.
- [ ] Starting another pedal from the same synth does not leave conflicting playback active.
- [ ] No intentional change is made to image-to-music output, cover appearance, or effect mapping.
- [ ] No planned feature, new dependency, persistence expansion, or legacy cleanup is implemented.
- [ ] Relevant tests pass.
- [ ] Debug and Release builds pass.
- [ ] `git diff --check` passes.
- [ ] Unrun physical-device validation is reported as pending, not completed.

## Test Scenarios

| Area | Scenario | Expected result |
| --- | --- | --- |
| Preparation | Same normalized synthetic pixels | Equal essential sequence data; no fingerprint assertion |
| Grid mapping | Four-tone level 0 | No note event for the grid cell |
| Grid mapping | Four-tone levels 1, 2, 3 | Note events with velocities 1/3, 2/3, 1 |
| Harmony | Threshold profiles | Existing scale selection and BPM bounds remain unchanged |
| Metadata | Valid generated draft | Generated validated name/description are used |
| Metadata | Unavailable/refused/failed/invalid draft | Valid static fallback is used; sequence/cover remain valid |
| Storage | Save then load | Equal stored pedal data and recoverable cover |
| Storage | Save later pedal | Later pair replaces prior latest pair |
| Storage | Missing JSON, missing PNG, or invalid pair | `loadLatest()` returns `nil` |
| Playback | Start, stop, start another pedal | One active playback path for the synth instance; clean stop state |
| Intents | Create/play router requests | Correct `AppIntentRouter.Request` value when testable |

## Manual Validation Matrix

Use the device matrix above together with `docs/DEVICE_VALIDATION.md`. At minimum, an implementation report must mark camera, photo import, Foundation Models fallback, speaker playback, headphones/route changes, interruption, foreground/background, Shortcuts/Siri, repeated creation/playback, and relaunch recovery as pass, fail, or not run.

## Observability

- Reuse existing `PhotoPedalViewModel.errorMessage`, `PedalProcessingStage`, and `AppError` reporting for user-visible failures.
- Add DEBUG-only diagnostics only when needed to distinguish a demonstrated metadata fallback, store failure, or playback-start failure during validation.
- Do not add analytics, persistent diagnostic records, or product-facing debug controls.

## Allowed Files and Areas

### Expected

- `snap-battle/Services/Pedal/PhotoPedalPipeline.swift`
- `snap-battle/Services/FoundationModels/FoundationModelsPedalGenerator.swift`
- `snap-battle/Domain/Pedal/Pedal.swift`
- `snap-battle/Services/Persistence/PedalStore.swift`
- `snap-battle/Services/Audio/PhotoPedalSynth.swift`
- `snap-battle/Features/Capture/CaptureViewModel.swift`
- `snap-battle/Intents/PhotoPedalIntents.swift`
- `snap-battleTests/PhotoPedalStabilizationTests.swift`

### Conditional

- `snap-battle/Features/Capture/CaptureView.swift`, only for a demonstrated state-routing or accessible error-state defect.
- `snap-battle/Supporting/AppError.swift`, only for a specific fallback or lifecycle error that cannot be represented by existing cases.
- `snap-battle/Services/Pedal/ImageSequenceGenerator.swift`, `PhotoColorAnalyzer.swift`, `snap-battle/Services/ImageInputPreparer.swift`, or `snap-battle/Services/ImageProcessing/RetroImageProcessor.swift`, only to correct a demonstrated violation of current tested behavior.

### Documentation

- `README.md`
- `docs/IMAGE_TO_MUSIC.md`
- `docs/AUDIO_SYSTEM.md`
- `docs/FOUNDATION_MODELS.md`
- `docs/TESTING.md`
- `docs/DEVICE_VALIDATION.md`
- This specification

## Prohibited Changes

- Do not alter the creative algorithm, scales, image-to-note mapping, cover aesthetic, effect mapping, or audio engine.
- Do not edit planned specifications as implementation authorization.
- Do not remove or broadly rename legacy code, including `CreatureMaterial`.
- Do not add gallery storage, migration, generator versioning, Board, sharing, collaboration, export, or new dependencies.
- Do not add unrelated visual changes, broad refactors, opportunistic optimization, or extensive visual snapshots.
- Do not create commits automatically.

## Open Questions

None. This specification defines the fallback metadata values and limits implementation to existing contracts.

Non-blocking follow-up: musical-variation, fingerprint-responsibility, generator-versioning, gallery, and Board decisions remain in separate planned work and are not part of this specification.

## Verification

Run focused and full tests using the shared scheme and an installed simulator:

```sh
xcodebuild test -project "Dap.xcodeproj" -scheme "snap-battle" -destination 'platform=iOS Simulator,name=<installed simulator>'
```

Build both configurations using the current project and scheme:

```sh
xcodebuild build -project "Dap.xcodeproj" -scheme "snap-battle" -configuration Debug
xcodebuild build -project "Dap.xcodeproj" -scheme "snap-battle" -configuration Release
git diff --check
```

Before completion, review the diff to confirm no out-of-scope files or intentional musical-output changes, no planned specification treated as authorization, and no automatic commit. Report all physical-device checks not run.
