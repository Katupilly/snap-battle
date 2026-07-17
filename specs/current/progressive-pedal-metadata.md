# Progressive Pedal Metadata

Status: Ready
Priority: P0
Last updated: 2026-07-16

## Context

Photo Pedal currently treats the playable result and semantic metadata as one
blocking pipeline result. The user sees `PedalResultView` only after image
preparation, cover generation, color analysis, sequence generation, subject
extraction, object analysis, Foundation Models generation, validation, and
persistence have completed.

Confirmed measurements after the image-preparation executor optimization:

- `imagePreparation` executes outside the MainActor.
- Observed `imagePreparation` duration is 8-17 ms.
- `metadataGeneration` takes approximately 1.3-1.7 s.
- `subjectExtraction` varies approximately between 160-950 ms.
- `pickerTransfer` remains variable and external to the pipeline.
- Cover generation, musical analysis, and persistence are fast.
- There is no evidence of a SwiftUI bottleneck.

The implementation already has collection storage through `PedalStore`, Gallery
state through `GalleryViewModel`, and result presentation through
`PedalResultView`. Some lower-level documents still describe only the legacy
latest-pedal storage contract; implementation and
[Navigation and Gallery Foundation](navigation-gallery-foundation.md) are the
current source for collection behavior.

References:

- [Product specification](../../docs/PRODUCT_SPEC.md)
- [Architecture](../../docs/ARCHITECTURE.md)
- [Data model](../../docs/DATA_MODEL.md)
- [Foundation Models integration](../../docs/FOUNDATION_MODELS.md)
- [Testing](../../docs/TESTING.md)
- [Import and legacy audit](../../docs/audits/photo-pedal-import-and-legacy-audit.md)
- [ADR 0001](../../docs/decisions/0001-deterministic-local-music-generation.md)
- [ADR 0002](../../docs/decisions/0002-persist-generated-musical-results.md)
- [ADR 0003](../../docs/decisions/0003-foundation-models-for-semantic-metadata.md)
- [ADR 0005](../../docs/decisions/0005-image-processing-concurrency-boundary.md)
- [Vertical Slice Stabilization](vertical-slice-stabilization.md)
- [Navigation and Gallery Foundation](navigation-gallery-foundation.md)
- [Image Preparation Executor Boundary](image-preparation-executor-boundary.md)

## Problem

The playable pedal waits for semantic enrichment that is not required for
playback. This delays the result screen by the slower subject extraction,
object analysis, and Foundation Models stages even after the cover and
deterministic musical sequence are ready.

The product contract is the opposite: music and cover are the essential result;
semantic metadata is enrichment. A pedal must remain valid, playable, and
persisted even when semantic metadata is slow, unavailable, refused, empty,
invalid, cancelled, or failed.

## Objective

Present and persist the playable pedal as soon as the cover and musical result
exist, using valid fallback metadata. Continue semantic enrichment afterward for
the same record, validate it, and update only `name` and `description` for that
existing `PhotoPedal.id`.

## User Outcome

A person can capture or import a photo, see the 2-bit cover, play the pedal,
adjust the effect, and find it in Gallery without waiting for the semantic name
and description. If enrichment later succeeds, the same visible pedal receives
its better name and description. If it fails, the fallback remains.

## Approved Flow

```text
Capture/import
-> image preparation
-> retro cover
-> color analysis
-> sequence generation
-> create PhotoPedal with valid fallback metadata
-> persist pedal
-> present PedalResultView
-> run semantic enrichment
-> validate generated metadata
-> update only name and description
-> refresh PedalResultView and Gallery for the same ID
```

The main acceptance criterion is that `PedalResultView` appears before
`subjectExtraction`, `objectAnalysis`, and `metadataGeneration` finish. This
specification does not set an arbitrary millisecond target without new
measurement.

## Product Principles

- Music and cover are the essential result.
- Foundation Models is enrichment, not a dependency.
- The user must not wait to play.
- The initial pedal must be complete and valid, not a placeholder.
- Late metadata must not change musical or visual identity.
- One creation must produce one Gallery item.
- Failure keeps the fallback rather than invalidating the pedal.

## In Scope

- Separate essential generation from semantic enrichment.
- Progressive result presentation after persistence of a valid fallback pedal.
- Metadata enrichment state for loading, success, failure, cancellation, and
  stale responses.
- A minimal store operation to update only `name` and `description` on an
  existing record.
- Refresh of the active result and Gallery detail/list for the same ID.
- Stale-response, deletion, duplicate-creation, cancellation, dismiss, and
  relaunch behavior.
- Focused tests for progressive result and metadata update behavior.
- DEBUG-only observability using run IDs and existing signpost style.

## Out of Scope

- Prompt wording or creative metadata style changes.
- New metadata properties.
- Manual metadata regeneration.
- User editing of names or descriptions.
- Musical generation, harmony, sound profile, effect, or cover changes.
- Downsampling or PhotosPicker optimization.
- UIKit migration.
- Legacy cleanup or broad renaming.
- Gallery redesign.
- Jam, collaboration, sharing, cloud sync, or new dependencies.

## Data Model

The persisted `PhotoPedal` schema remains unchanged. The initial record is a
normal `PhotoPedal` with:

- a new UUID;
- `createdAt` set at initial creation;
- the generated `PedalSequence`;
- selected effect and sound profile;
- the processed cover filename;
- fallback name `Photo Pedal`;
- fallback description `A photo-generated sound pedal.`.

The fallback values are valid under `PedalDraftValidator` and must be persisted
before result presentation.

Semantic enrichment may alter only:

- `name`;
- `description`.

Semantic enrichment must not alter:

- `id`;
- `createdAt`;
- `sequence`;
- `harmony`;
- sound profile;
- `effect`;
- effect parameters;
- cover image;
- `coverFilename`.

No persistent `metadataStatus`, `runID`, pending flag, original image, Vision
observation, prompt, generator version, or semantic context is added in this
specification. Metadata-pending state is ephemeral UI/session state.

## State Model

The active creation has two independent state tracks:

| Track | States | Owner |
| --- | --- | --- |
| Essential creation | idle, preparing, making cover, saving, presented, failed, cancelled | `PhotoPedalViewModel` on MainActor |
| Semantic enrichment | notStarted, loading, succeeded, failed, cancelled, staleIgnored | `PhotoPedalViewModel` on MainActor |

`PedalResultView` reads the current pedal value and an accessible enrichment
state. Gallery reads persisted records from `PedalStore` and updates by ID.

The user-facing result must never show technical wording such as Foundation
Models, Vision, inference, or metadata. Acceptable language is product-facing,
for example a subtle "Refinando nome..." progress state while playback remains
enabled.

## Persistence Strategy

`PedalStore.save(_:cover:)` remains the operation for creating the initial
record. It must be called immediately after the essential result is available
and before `PedalResultView` is presented.

Add one narrow store operation for semantic updates, conceptually:

```swift
func updateMetadata(id: UUID, name: String, description: String) throws -> StoredPedal
```

The exact signature may include diagnostics parameters, but the operation must:

- load the existing record by ID;
- fail if the record does not exist or has been deleted;
- validate the new `PedalDraft` before writing;
- create a replacement `PhotoPedal` preserving every field except `name` and
  `description`;
- reuse the existing cover file without rewriting or regenerating the cover;
- write through the same safe JSON validation/promotion rules used by
  collection persistence;
- return the updated stored pedal or enough data for callers to refresh the
  current item;
- not create a record when the ID is missing;
- not expose a broad generic edit API.

The same `PhotoPedal.id` must remain visible in Gallery. A metadata update is
an update to the existing list/detail item, never an insertion.

## Concurrency Strategy

`PhotoPedalViewModel` owns the creation task and the enrichment task for the
capture/result flow. Both update UI state only on the MainActor. Essential
image/music generation remains sequential and must not wait on semantic
enrichment.

Each creation receives:

- a `creationID`, equal to the persisted `PhotoPedal.id`;
- a diagnostics `runID`, propagated through essential and semantic signposts;
- an ephemeral `enrichmentToken`, unique to that enrichment attempt.

The enrichment task starts only after the fallback pedal has been saved and
presented. It receives the prepared image representation needed by subject
extraction/object analysis, the immutable sequence harmony, `creationID`,
`runID`, and `enrichmentToken`.

Before applying generated metadata, the task must verify on MainActor:

- the task was not cancelled;
- the active enrichment token still matches;
- the current result, if any, still has `creationID`;
- the store still contains `creationID`;
- the generated draft validates successfully.

If any check fails, the response is stale and must be ignored. It must not
recreate a deleted pedal, must not update a newer capture, and must not present
or insert a second Gallery item.

Starting a new capture cancels the previous active creation/enrichment tasks
owned by that capture flow and assigns new identifiers. Late responses from the
previous run are ignored even if cancellation is not observed promptly by a
framework call.

Deleting a pedal while enrichment is pending wins over enrichment. The later
store update must fail as missing/deleted and the response must be ignored.

## Lifecycle Behavior

### Result Dismissal

Closing `PedalResultView` after the fallback pedal has been saved keeps the
record. The enrichment task may continue as structured work owned by the
capture flow or a small coordinator retained long enough to finish the current
attempt. If the flow object is deallocated and cancels the task, the fallback
remains valid.

The required behavior is:

- dismissing result must not delete or duplicate the pedal;
- a successful post-dismiss enrichment updates the same persisted record;
- Gallery refreshes or observes the update by ID when it next loads or when the
  coordinator publishes completion;
- if the task is cancelled by lifecycle, fallback remains.

### Background And Relaunch

If the app backgrounds while enrichment is running, no background execution
guarantee is required. The task may finish, be suspended, or be cancelled by
normal app lifecycle.

Pending metadata is not persisted as state. On relaunch, a fallback-only pedal
loads as a complete valid pedal and `PlayLastPedalIntent` can play it. This
spec does not require automatic resume or retry of semantic enrichment after
relaunch.

### Cancellation

Cancellation before essential persistence creates no record. Cancellation after
essential persistence keeps the fallback record and stops further semantic UI
updates unless enrichment already completed safely for the same ID.

### New Capture

A new capture has a new `PhotoPedal.id`, run ID, and enrichment token. Metadata
from a previous capture cannot update the newer pedal because application
requires both ID and token checks.

## UX Requirements

`PedalResultView` must present immediately after fallback persistence with:

- cover;
- play control;
- effect selector and intensity;
- musical summary/grid;
- fallback name/description or a product-facing visual equivalent;
- a nonblocking indication while the name/description are being refined.

Playback, effect selection, done/dismiss, and Gallery navigation remain enabled
while enrichment is loading.

When enrichment succeeds, update visible text in place for the same pedal. The
update must not move the user away from the screen, restart playback, reset
effect selection, or animate in a way that violates Reduce Motion.

When enrichment fails, returns empty content, or validates invalidly, keep the
fallback and show no blocking error. A quiet product-facing failure state is
allowed, but the pedal must remain playable and saved.

Accessibility requirements:

- VoiceOver must announce the loading state and any completed name/description
  update without relying on color alone.
- Dynamic Type must keep fallback/progress/success text readable without
  overlap.
- Reduce Motion must disable or simplify any text-replacement animation.
- The progress copy must avoid technical terms: Foundation Models, Vision,
  inference, and metadata.

## Gallery And Detail Refresh

Gallery must update an existing item by `PhotoPedal.id` after metadata
enrichment succeeds. It may do this by reloading the collection or by applying
the returned updated stored pedal to current state. Either approach must:

- preserve collection ordering unless `createdAt` or ID order changes, which
  this spec forbids;
- preserve the current detail route for that ID;
- update the detail screen if it is showing the same ID;
- not create a duplicate card;
- not hide valid records if the update refresh encounters unrelated partial
  load issues.

If Gallery is not visible, the next reload must show the updated name and
description from storage.

## App Intents

`PlayLastPedalIntent` uses the shared latest selection from `PedalStore`.
While semantic enrichment is pending, it plays the fallback-persisted pedal
using the persisted sequence and sound profile. It must not wait for
enrichment, generate metadata, recalculate music, or create a replacement
record.

If enrichment succeeds before the intent runs, the intent may surface the
updated name through normal UI state, but playback behavior is identical. If
enrichment fails or is cancelled, playback still works with fallback metadata.

`CreatePedalIntent` continues to route to capture and does not perform
background capture, pipeline execution, or enrichment itself.

## Failure Handling

| Condition | Required result |
| --- | --- |
| Subject extraction unavailable/fails | Continue to object analysis if possible or fallback semantic flow; keep playable pedal. |
| Object analysis fails | Keep fallback metadata. |
| Foundation Models unavailable/refused/fails | Keep fallback metadata. |
| Generated name/description empty or invalid | Keep fallback metadata. |
| Store metadata update fails | Keep fallback in memory/storage and expose only nonblocking recoverable state if needed. |
| Enrichment response is stale | Ignore without user-facing error. |
| Pedal was deleted | Do not recreate it; ignore update. |
| New capture started | Do not update previous or current pedal unless ID/token match. |
| Result dismissed | Keep saved fallback; enrichment may update same ID if still running. |
| Relaunch before enrichment succeeds | Load fallback as valid final state; no required retry. |

## Observability

Keep DEBUG-only diagnostics and existing run ID correlation. Add signposts or
events only as needed to distinguish:

- time to musical result;
- time to semantic enrichment;
- total pipeline semantic time;
- enrichment started/succeeded/failed/cancelled/stale-ignored;
- metadata update write duration.

Do not log image content, pixel data, filenames, prompts, generated private
content beyond high-level state, Vision labels, or personal metadata. Release
builds must not emit active diagnostic instrumentation.

## Testing Requirements

Add focused tests using seams/doubles; do not depend on live Foundation Models,
camera hardware, audio hardware, network, or binary photo fixtures.

Required scenarios:

- result is presented before semantic enrichment completes;
- fallback metadata is persisted before result presentation;
- valid semantic metadata updates the same `PhotoPedal.id`;
- invalid semantic metadata keeps fallback;
- semantic error keeps fallback;
- stale response is ignored;
- deleted pedal is not recreated by late enrichment;
- a new capture does not receive metadata from the previous capture;
- Gallery updates the existing item;
- no second Gallery item is created;
- music, sound profile, effect, cover, cover filename, ID, and `createdAt`
  remain identical after metadata update;
- `PlayLastPedalIntent` works while enrichment is pending;
- cancellation and result dismiss keep a valid fallback pedal;
- relaunch with fallback persisted loads and plays without required enrichment
  retry.

Preserve existing deterministic generation, storage, Gallery, App Intent, and
image-preparation tests. Add no broad visual snapshot suite unless a specific
UI regression cannot be tested otherwise.

## Device Validation Requirements

Manual validation must record pass, fail, or not run for:

- library import and camera capture showing result before semantic enrichment
  finishes;
- immediate playback while enrichment is pending;
- eventual visible name/description update;
- enrichment failure/fallback behavior on an unavailable or refused model path
  where feasible;
- dismissing result while enrichment is pending;
- deleting a pending-enrichment pedal from Gallery;
- background/foreground while enrichment is pending;
- relaunch with fallback-only persisted pedal;
- VoiceOver, Dynamic Type, and Reduce Motion behavior;
- `PlayLastPedalIntent` during pending enrichment and after enrichment success.

## Performance Acceptance

Measure and report:

- time to musical result: capture/import handoff through fallback persistence
  and result presentation;
- time to semantic enrichment: enrichment task start through validated metadata
  or fallback failure decision;
- total pipeline semantic time: subject extraction, object analysis,
  metadata generation, and validation/update completion under the same run ID.

Primary criterion:

- `PedalResultView` appears before `subjectExtraction`, `objectAnalysis`, and
  `metadataGeneration` finish.

No fixed millisecond target is required by this spec. Preserve signposts and
run IDs so future device measurements can compare real improvements.

## Allowed Files And Areas

### Expected

- `snap-battle/Services/Pedal/PhotoPedalPipeline.swift`
- `snap-battle/Features/Capture/CaptureViewModel.swift`
- `snap-battle/Features/Capture/CaptureView.swift`
- `snap-battle/Features/Pedal/PedalResultView.swift`
- `snap-battle/Services/Persistence/PedalStore.swift`
- `snap-battle/Features/Gallery/GalleryViewModel.swift`
- `snap-battle/Features/Gallery/GalleryView.swift`
- `snap-battle/Domain/Pedal/Pedal.swift`, only for a narrow metadata-preserving
  helper if needed
- focused tests under `snap-battleTests/`

### Conditional

- `snap-battle/Supporting/PerformanceDiagnostics.swift`, only for DEBUG-only
  run ID/signpost coverage listed above.
- `snap-battle/Supporting/AppError.swift`, only if an existing error cannot
  represent missing/deleted metadata update failure.
- A new small service/coordinator under `snap-battle/Services/Pedal/` or
  `snap-battle/Features/Capture/`, only if it keeps enrichment ownership more
  localized than expanding view code.
- `snap-battle/Intents/PhotoPedalIntents.swift`, only if routing tests reveal a
  pending-metadata regression.

### Documentation

- This specification.
- Directly affected docs only if implementation changes make them inaccurate.

## Prohibited Changes

- Do not alter music generation, cover generation, effect mapping, sound
  rendering, or persisted musical data.
- Do not add a generic edit API for `PhotoPedal`.
- Do not add persistent pending-metadata state.
- Do not add retry policies, timeouts, background tasks, or relaunch enrichment
  resume.
- Do not add new dependencies.
- Do not log personal image or prompt content.
- Do not treat stale metadata as a reason to recreate records.
- Do not redesign Gallery, result, navigation, Jam, or legacy code.
- Do not create commits automatically.

## Acceptance Criteria

- [ ] The fallback pedal is valid and persisted immediately after essential
      cover/music generation.
- [ ] `PedalResultView` appears before subject extraction, object analysis, and
      Foundation Models metadata generation complete.
- [ ] Playback and effect controls work while enrichment is pending.
- [ ] Valid enrichment updates only `name` and `description` for the same ID.
- [ ] Invalid, empty, refused, unavailable, failed, cancelled, or stale
      enrichment keeps fallback metadata.
- [ ] Late enrichment cannot update a newer capture.
- [ ] Late enrichment cannot recreate a deleted pedal.
- [ ] Gallery and detail update the existing item by ID without duplicate
      insertion.
- [ ] `id`, `createdAt`, sequence, harmony, sound profile, effect, effect
      parameters, cover, and `coverFilename` remain unchanged.
- [ ] `PlayLastPedalIntent` plays the persisted fallback pedal while enrichment
      is pending.
- [ ] Relaunch with fallback-only metadata loads a valid pedal and does not
      require enrichment retry.
- [ ] VoiceOver, Dynamic Type, and Reduce Motion behavior remain acceptable.
- [ ] Required focused tests pass.
- [ ] Full simulator test suite passes.
- [ ] Debug and Release builds pass.
- [ ] `git diff --check` passes.
- [ ] Unrun device validation is reported as not run.

## Open Questions

None. This specification resolves the lifecycle, persistence, stale-result,
Gallery refresh, pending-state, App Intent, cancellation, and failure behavior
needed for `Status: Ready`.

Nonblocking follow-ups remain separate: prompt improvements, manual metadata
regeneration, editable names, retry/resume policy, background tasks, broader
Gallery polish, generator versioning, and legacy cleanup.

## Verification

Future implementation must run focused tests, the full simulator suite, Debug
and Release builds, and whitespace validation:

```sh
xcodebuild test -project "snap-battle.xcodeproj" -scheme "snap-battle" -destination 'platform=iOS Simulator,name=<installed simulator>'
xcodebuild build -project "snap-battle.xcodeproj" -scheme "snap-battle" -configuration Debug
xcodebuild build -project "snap-battle.xcodeproj" -scheme "snap-battle" -configuration Release
git diff --check
```

This documentation-only task must run `git diff --check` and must not run
Swift builds or tests unless explicitly requested.

## Implementation Authorization

This Ready specification authorizes future localized implementation of
progressive result presentation and post-result semantic enrichment within the
allowed files and constraints above. It does not authorize any code change in
the documentation-only turn that creates this file.
