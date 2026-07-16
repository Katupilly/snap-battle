# Image Preparation Executor Boundary

Status: Draft
Priority: P0
Last updated: 2026-07-16

## Goal

Remove the confirmed synchronous `imagePreparation` block from the MainActor
without changing the visual, musical, persistence, cancellation, or result
presentation behavior of the Photo Pedal flow.

The device evidence motivating this spec is a warmed median of 196.3 ms and a
maximum of 394.5 ms for `imagePreparation` on the main executor. This spec does
not target the approximately 4.5 s end-to-end wall-clock time: `pickerTransfer`
and semantic metadata are separate performance concerns.

## Status rationale and blocker

This remains `Draft`, so it does not authorize implementation. Inspection found
two unresolved decisions:

1. `PhotoPedalPipeline` and `PhotoPedalViewModel` are `@MainActor`, while
   `PreparedImage` crosses the existing boundary as `@unchecked Sendable` and
   stores a `UIImage` ([ImageInputPreparer.swift:5-10](../../snap-battle/Services/ImageInputPreparer.swift#L5-L10)).
   The code has no approved immutable representation for sending prepared image
   data to another executor without adding another unsafe suppression.
2. The repository documentation says Swift 6, but the project declares
   `SWIFT_VERSION = 5.0` in `snap-battle.xcodeproj/project.pbxproj` at the app
   and test configurations. The implementation must first decide whether to
   validate the boundary under the current language mode or separately migrate
   strict concurrency. This spec does not authorize that migration.

Before changing the status to `Ready`, resolve these decisions and prove the
chosen representation with the project's compiler and SDK. Do not solve the
blocker with `Task.detached` indiscriminately or a new `@unchecked Sendable`.

## Current context

The active path is:

`CaptureView` → `PhotoPedalViewModel.process/load` → `PhotoPedalPipeline.run` →
`ImageInputPreparer.prepare` → cover/color/sequence generation → Vision and
Foundation Models metadata → persistence → `PedalResultView`.

Inspected symbols and current locations:

- `PhotoPedalViewModel` and the inherited `Task` in
  `snap-battle/Features/Capture/CaptureViewModel.swift:4-55`.
- PhotosPicker transfer, camera handoff, and MainActor UI state in
  `snap-battle/Features/Capture/CaptureView.swift:109-153`.
- `PhotoPedalPipeline.run(image:runID:stage:)` in
  `snap-battle/Services/Pedal/PhotoPedalPipeline.swift:3-101`.
- `ImageInputPreparer.prepare`, orientation normalization, and fingerprint in
  `snap-battle/Services/ImageInputPreparer.swift:5-74`.
- `PreparedImage`'s current `UIImage` boundary in
  `snap-battle/Services/ImageInputPreparer.swift:5-10`.
- `RetroImageProcessor.process` is already `nonisolated` and uses a detached
  task in `snap-battle/Services/ImageProcessing/RetroImageProcessor.swift:4-50`;
  it is not a reason to broaden parallelism in this change.
- `PhotoColorAnalyzer.analyze` in
  `snap-battle/Services/Pedal/PhotoColorAnalyzer.swift:4-30`.
- `ImageSequenceGenerator.makeSequence` in
  `snap-battle/Services/Pedal/ImageSequenceGenerator.swift:4-17`.
- Reused `SubjectExtracting` and `ObjectAnalyzing` MainActor protocols in
  `snap-battle/Services/Pipeline.swift:5-14`.
- `SubjectExtractionService.extract` in
  `snap-battle/Services/Vision/SubjectExtractionService.swift:21-48`.
- `VisionObjectAnalyzer.analyze` and its `CGImage` conversion in
  `snap-battle/Services/Vision/VisionObjectAnalyzer.swift:5-23`.
- DEBUG-only signposts in
  `snap-battle/Supporting/PerformanceDiagnostics.swift:13-73`.
- Existing focused deterministic, orientation, fingerprint, cover, and
  sequence tests in `snap-battleTests/PhotoPedalStabilizationTests.swift:8-128`
  and `snap-battleTests/CreatureAuditTests.swift:42-76`.

Relevant contracts are defined by [Architecture](../../docs/ARCHITECTURE.md),
[Image-to-Music](../../docs/IMAGE_TO_MUSIC.md), [Testing](../../docs/TESTING.md),
[the import audit](../../docs/audits/photo-pedal-import-and-legacy-audit.md),
the current vertical-slice and navigation specs, and ADRs 0001, 0002, and 0003.

## Proposed boundary, pending resolution

The preferred minimal design is a dedicated serial image-preparation service
or actor. It must accept only an explicitly immutable, compiler-accepted image
representation and return an immutable prepared value plus value metadata.

The implementation investigation should evaluate, in this order:

1. A `Sendable` service operating on an immutable `CGImage` boundary, if the
   current SDK/compiler accepts that boundary without project-local
   `@unchecked Sendable`.
2. Otherwise, an immutable byte-buffer representation with explicit color,
   dimensions, and orientation metadata, only if it preserves current pixels
   and does not retain unnecessary full-resolution copies.
3. A dedicated actor around the selected service if serialization or ownership
   is required. The actor must not run independent pipeline stages concurrently.

`UIImage` must be created or consumed only on the side of the boundary where
the platform contract permits it. The existing `PreparedImage` type must not
continue to cross executors solely because of a new unchecked conformance.
The chosen boundary must preserve current orientation normalization and
CoreGraphics rendering semantics; introducing downsampling, a new format, or a
new resolution is out of scope.

The pipeline remains sequential:

```text
MainActor UI state
  → immutable image boundary
  → serial image preparation executor
  → prepared immutable value
  → MainActor pipeline/UI handoff
  → existing cover → color → sequence → metadata → persistence → result order
```

The return hop to MainActor is allowed only for existing UI state updates:
`stage`, `isProcessing`, `pendingPedal`, `pendingCover`, errors, and final
presentation state. No result may update the ViewModel after cancellation.

## Functional requirements

- The same selected or captured image produces the same normalized orientation,
  dimensions, pixels, fingerprint, four-tone cover, `PhotoColorProfile`,
  `PedalSequence`, persistence result, and `PedalResultView` content.
- `isProcessing` remains the duplicate-processing lock and returns to `false`
  after success, cancellation, or error.
- The existing cancellation checks remain in force; add checks immediately
  before dispatch and immediately after synchronous preparation where the
  selected boundary permits.
- Cancellation must not present or persist a result that completed after the
  cancellation decision.
- Each input is prepared exactly once per pipeline invocation.
- The order `pipeline → persistence → result` remains unchanged.
- Existing errors continue through the current ViewModel error path.
- Existing DEBUG signposts and run IDs remain correlated. `imagePreparation`
  must report a non-main executor without recording personal image content.
- Release builds continue to evaluate no active diagnostics instrumentation.

## Concurrency and memory requirements

- `imagePreparation` must not execute on the MainActor.
- No mutable `UIImage` instance may be shared between executors.
- Do not add `Task.detached` as a generic escape hatch.
- Do not add `@unchecked Sendable`, compiler suppressions, or data-race-prone
  shared state.
- Document the ownership and immutability of the selected image boundary.
- Avoid retaining both redundant full-resolution source and prepared buffers
  longer than the existing pipeline requires.
- Do not move Vision, Foundation Models, metadata, persistence, PhotosPicker,
  UIKit architecture, or legacy cleanup into this change.

## Contract of equivalence

For the same fixture and current algorithm, compare:

- normalized orientation;
- original and processed dimensions;
- normalized pixels using a documented pixel comparison or stable immutable
  representation;
- fingerprint;
- four-tone cover pixels/dimensions;
- `PhotoColorProfile`;
- `PedalHarmony`, ordered `PedalNote` values, and `PedalSoundProfile`.

`UUID`, `createdAt`, generated name, generated description, and other semantic
metadata are excluded from this equivalence contract.

## Required tests

Add or adapt focused tests only in the areas authorized below:

- repeated preparation of the same fixture;
- orientation normalization and dimensions;
- fingerprint equality;
- normalized pixel or stable-representation equivalence;
- cover equivalence;
- color-profile and sequence equivalence;
- cancellation before dispatch;
- cancellation during or immediately after preparation, using a deterministic
  seam rather than sleep-based timing where possible;
- no ViewModel state update or result presentation after cancellation;
- duplicate `process` calls still produce one execution;
- existing fingerprint, orientation, cover, deterministic-generation,
  metadata-fallback, and pipeline error tests remain passing.

Do not require timing sleeps or `Thread.isMainThread` as the sole executor
assertion. Prefer an explicit executor-injected test seam, actor isolation,
or a concurrency assertion that reflects Swift Concurrency's executor model.

## Allowed files and areas

Only the following areas may be changed by a future implementation of this
spec, after it is promoted to `Ready`:

- `snap-battle/Features/Capture/CaptureViewModel.swift`, only for the async
  handoff, cancellation, duplicate prevention, and MainActor state updates.
- `snap-battle/Services/Pedal/PhotoPedalPipeline.swift`, only for the serial
  preparation boundary and unchanged sequential handoff.
- `snap-battle/Services/ImageInputPreparer.swift`, including `PreparedImage`,
  only to establish the approved immutable representation and preserve output.
- One new focused image-preparation service/actor under
  `snap-battle/Services/`, only if required by the selected boundary.
- `snap-battle/Supporting/PerformanceDiagnostics.swift`, only to report the
  executor accurately without adding personal data or Release instrumentation.
- Focused tests under `snap-battleTests/` covering the contracts above.
- Directly affected documentation or this specification.

Do not authorize changes to PhotosPicker, `CaptureView` UI behavior,
`RetroImageProcessor`, `PhotoColorAnalyzer`, `ImageSequenceGenerator`, Vision,
Foundation Models, metadata flow, persistence, Gallery, `PedalResultView`,
legacy Snap Battle code, project language mode, dependencies, or output
algorithms unless the unresolved boundary decision explicitly requires a
separate approved specification.

## Acceptance criteria

- [ ] `imagePreparation` does not execute on the MainActor.
- [ ] SwiftUI/ViewModel state is updated only on the MainActor.
- [ ] The same fixture produces equivalent normalized output.
- [ ] Fingerprint remains identical.
- [ ] Cover remains equivalent.
- [ ] Color profile and sequence remain identical.
- [ ] Cancellation does not present or persist a later result.
- [ ] No duplicate execution is introduced.
- [ ] No new unsafe Sendable suppression is added.
- [ ] No intentional output change is made.
- [ ] Focused tests and the complete test suite pass.
- [ ] Debug and Release builds pass.
- [ ] `git diff --check` passes.
- [ ] Three warmed physical-device runs show `imagePreparation` off the main
      executor with the same run ID correlation.
- [ ] If physical measurement is unavailable, it is reported as `not run`.

## Measurement of success

Mandatory success is removal of the confirmed MainActor block. Improved
perceived responsiveness is expected but not guaranteed. A substantial
reduction of the approximately 4.5 s complete wall-clock flow is explicitly
outside this spec and must not become an acceptance target.

For the physical check, manually use three warmed runs with a documented
fixture and compare the existing `imagePreparation` signpost. Do not infer
iCloud origin from a `PhotosPickerItem`; classify local/remote scenarios in the
experiment notes instead.

## Verification commands

Do not run these commands as part of this documentation task. Future
implementation validation should use:

```sh
xcodebuild test -project "snap-battle.xcodeproj" -scheme "snap-battle" -destination 'platform=iOS Simulator,name=<installed simulator>' -only-testing:snap-battleTests/PhotoPedalStabilizationTests
xcodebuild test -project "snap-battle.xcodeproj" -scheme "snap-battle" -destination 'platform=iOS Simulator,name=<installed simulator>'
xcodebuild build -project "snap-battle.xcodeproj" -scheme "snap-battle" -configuration Debug
xcodebuild build -project "snap-battle.xcodeproj" -scheme "snap-battle" -configuration Release
git diff --check
```

The physical validation must be performed on a real device with three warmed
imports and a comparison of `imagePreparation` executor details and the
unchanged run ID through `totalPipeline`.

## Non-goals

No PhotosPicker change, downsampling, resolution or format change, fingerprint
change, algorithm change, musical-generator change, concurrent independent
stages, progressive metadata, post-result Foundation Models work, persistence
change, UIKit migration, legacy cleanup, broad pipeline rewrite, dependency,
or automatic commit is authorized.

## Open questions / promotion gate

Resolve and document:

1. Is an immutable `CGImage` boundary accepted by the current SDK and compiler
   without a project-local unsafe conformance?
2. If not, what immutable bytes representation preserves the exact current
   normalized pixels, orientation, dimensions, and color semantics without
   redundant full-resolution retention?
3. Does this boundary need a dedicated actor, or can a `Sendable` service with
   an async nonisolated method provide the same serialized ownership?
4. Will the implementation be validated under the project's current Swift 5.0
   setting, or is a separately approved language-mode migration required?

Promote this document to `specs/current/` with `Status: Ready` only after these
questions are resolved and a compile-checked boundary is selected. Until then,
this Draft is not implementation authorization.
