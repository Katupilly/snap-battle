# Spec: Navigation and Gallery Foundation

Status: Ready
Priority: P0
Last updated: 2026-07-22

## Context

The active Dap vertical slice captures or imports an image, creates a four-tone cover and deterministic `PedalSequence`, generates metadata or fallback metadata, automatically persists the result, and presents `PedalResultView`. `ContentView` is in `Dap/Features/Capture/CaptureView.swift`; it currently presents either the private `PedalCaptureView` or `PedalResultView` in one `NavigationStack`. `CameraScreen` is a sheet and photo-library import uses `PhotosPicker`.

`DapViewModel.process(_:)` in `Dap/Features/Capture/CaptureViewModel.swift` blocks duplicate processing with `isProcessing`, runs `DapPipeline`, updates in-memory state, and calls `PedalStore.save(_:cover:)`. `PedalStore` currently writes only `latest-pedal.json` and `latest-pedal.png` in Application Support. `PhotoPedal` in `Dap/Domain/Pedal/Pedal.swift` already has UUID identity, creation date, final sequence, effect, sound settings, metadata, and a cover filename.

This work follows [ADR 0001](../../docs/decisions/0001-deterministic-local-music-generation.md), [ADR 0002](../../docs/decisions/0002-persist-generated-musical-results.md), and [ADR 0003](../../docs/decisions/0003-foundation-models-for-semantic-metadata.md). `docs/ROADMAP.md` mentions original-image retention and `generatorVersion`; those are lower-precedence planned direction and are intentionally excluded. The current model, ADR 0002, and this specification persist only the processed cover and final musical data.

## Authority Boundary

This specification remains the source of truth for the implemented navigation and persistence foundation: persistent Gallery and Jam roots, transient Capture, automatic save/result completion, collection storage, legacy migration, safe writes, deletion, playback coordination, App Intent routing, and shared latest-pedal selection.

It is no longer the source of truth for the future visual Library experience. The future Photos-like Library grid, chronological visual order, month grouping, initial scroll position, shared-element transition, standardized detail cover frame, and scroll preservation are governed by [Dap Library](pedal-library.md).

Until that promotion happens, the implemented Gallery list remains valid current behavior. Do not use the baseline list/card requirements in this foundation spec to block or override the future Library feature spec.

## Problem

The app opens into a single capture-or-latest-result flow. It has no persistent Gallery or Jam destinations, no collection of reusable pedals, and no migration path from latest-pedal storage. Treating Capture as a destination would also leave no stable route to Gallery after creation.

## Objective

Introduce navigation and persistence foundations for a Gallery of multiple saved pedals while preserving current capture, processing, automatic persistence, deterministic music, and result review. Establish Jam only as a future individual-composition destination.

## User Outcome

A person opens Gallery, browses and replays saved pedals, inspects or deletes one, and starts a new capture. A newly processed pedal saves automatically, remains in `PedalResultView` for review, and appears in Gallery when the person completes or closes that result. Jam communicates future individual composition without requiring multiplayer.

## Product Model

### Pedal

A pedal is one photo-generated record: processed cover, persisted final musical result, selected effect and sound settings, metadata, UUID identity, and creation date. It replays stored musical data without recalculation.

### Gallery

Gallery is the persistent collection of pedals, not an alias for the latest pedal. This foundation established a baseline newest-first list under the shared deterministic ordering rule. A future Library visual layer may present the same persisted collection in a different visual order when authorized by a later current specification.

### Jam

A Jam is an individual composition made from an ordered sequence of pedals. This stage creates only its product concept and navigation destination; it creates no Jam model, persistence, ordering, or playback.

### Collaboration

Collaboration is an optional future action inside an existing Jam. It is not a primary destination or requirement here.

## Confirmed Current Behavior

- `ContentView` owns `DapViewModel`, selected `PhotosPickerItem`, and camera-sheet presentation. It handles `AppIntentRouter.Request.create` by resetting the model and opening `CameraScreen`, and `.playLast` by calling `DapViewModel.playLast()`.
- `CameraScreen` dismisses itself for cancellation and supplies a captured `UIImage` to `DapViewModel.process(_:)`; photo-library selection calls `load(data:)`, which reaches the same processing method.
- `DapPipeline.run(image:stage:)` creates the cover, deterministic sequence, metadata or fallback metadata, and a new `PhotoPedal`; it does not save itself.
- `DapViewModel.process(_:)` automatically saves a successful result before the UI changes to `PedalResultView`. There is no explicit save action.
- `PedalResultView` displays cover, metadata, sequence grid, effect controls, playback, and `Criar outro`; effect changes currently rewrite the latest-pedal pair.
- `PedalStore.loadLatest()` returns `nil` if either current legacy file is missing, unreadable, or incomplete.
- `CreatePedalIntent` and `PlayLastPedalIntent` set `AppIntentRouter.shared.request`; they do not duplicate pipeline, storage, or audio work.
- `DapSynth.play(_:)` stops existing playback before starting another pedal from the same synth instance.

## Navigation Model

The app has two persistent destinations, Gallery and Jam. Capture is one central action, not a third persistent tab or selected navigation state.

### Root-owned stack revision (authorized 2026-07-22)

This section supersedes earlier language in this specification that describes one global `NavigationStack`, one shared route type, or clearing a root path when another root is selected.

- Gallery and Jam are persistent sibling roots. Each owns one persistent `NavigationStack` and an independently typed path.
- `GalleryRoute.inspector(UUID)` is owned only by Gallery. The route stores the persisted UUID, never a `StoredPedal` or collection index.
- Jam uses its own route type and never stores Gallery routes.
- Switching roots preserves both paths and the state already mounted inside each root.
- Capture remains a transient shell presentation outside both root stacks. Cancellation restores the previously selected root; successful completion selects Gallery according to the existing completion contract.
- Root navigation chrome and Capture are shell-owned siblings of the root stacks. Their visibility is derived from the selected root, the active root path, Capture presentation, and Gallery selection chrome; they remain mounted outside Gallery's stack transition lifecycle.
- App Intents and external routes select the owning root before mutating only that root's path.
- Gallery's shared-element Hero is removed from the current delivery. Photo Inspector remains `GalleryRoute.inspector(UUID)` and uses the default native `NavigationStack` push. Hero continuity is deferred to a future isolated spike; overlays, manual matched geometry, custom gestures, global fades, delays, offsets, and snapshot transitions are not authorized.

See [ADR 0006](../../docs/decisions/0006-persistent-root-navigation-stacks.md).

- Gallery is initially selected.
- Jam is available through the main navigation control.
- Triggering Capture records the current destination and opens the existing camera/import flow in a modal or equally transient native presentation.
- Cancelling capture or import before successful processing returns to the previous destination and creates no record.
- Processing and automatic persistence succeed before `PedalResultView`; the app must not navigate immediately to Gallery.
- The result provides a final action semantically equivalent to Done or View in Gallery. Exact copy and visual design are nonbinding. The action closes capture/result presentation, selects Gallery, and makes the new pedal visible.
- Dismissing the result after automatic persistence keeps the saved pedal; it does not delete it.
- Native `TabView` is acceptable. A custom composition is allowed only if it preserves these behaviors and the accessibility requirements; no visual tab-bar design or pixel values are prescribed.

## Baseline Gallery Model

Gallery supports persisted-pedal browsing, detail, quick playback, creation, deletion, and an understandable empty state. The foundation baseline orders valid pedals by `createdAt` descending, then `id.uuidString` ascending when dates tie.

Each baseline card shows at least the processed cover, name, and an accessible playback state or action. Quick play and opening detail are separate discoverable controls in the baseline implementation; a later Library spec may replace the card/list interaction model. Gallery does not require BPM, scale, MIDI, HSL, fingerprint, or `generatorVersion` presentation.

## Capture Action Model

Capture reuses `CameraScreen`, `PhotosPicker`, `DapViewModel`, and `DapPipeline`; it does not authorize reconstruction of the vertical slice. The processing lock, metadata fallback, deterministic music, cover algorithm, and automatic persistence remain unchanged. A failed save keeps the processed result available for controlled retry rather than treating it as saved. No camera zoom, exposure, or advanced controls are introduced.

## Jam Placeholder Model

Jam presents an accessible empty state communicating an individual outcome equivalent to “Combine seus pedais para criar uma música.” It may show a clearly unavailable future action, but must not create a Jam record or suggest multiplayer is required.

## In Scope

- Main navigation shell with persistent Gallery and Jam destinations and a transient Capture action.
- Gallery collection persistence, idempotent legacy migration, and a Gallery UI/state owner.
- Baseline Gallery cards, empty/loading/content/error states, detail, quick play, and deletion.
- Result completion/dismiss integration after existing automatic save.
- Shared latest-pedal selection for storage and `PlayLastPedalIntent`.
- Focused persistence, navigation, Gallery, playback-coordination, and App Intent routing tests.
- Documentation updates caused directly by implementation.

## Out of Scope

- Jam creation/persistence, reordering, drag and drop, sequential playback, loop, global BPM, and adding pedals to Jam.
- Collaboration, iPhone connections, SharePlay, AirDrop, Jam import/export, and video export.
- Cover sharing/export, folders, tags, search, filters, favorites, cloud sync, social feed, multi-selection, and manual Gallery ordering.
- Original-image retention, destructive editing, camera controls, visual filters, dithering modes, musical-algorithm changes, fingerprint use, and `generatorVersion`.

## Functional Requirements

- Provide persistent Gallery and Jam destinations plus one nonpersistent Capture action.
- List every valid persisted pedal under the foundation's shared deterministic ordering rule.
- Allow creating, quick-playing, inspecting, and deleting a pedal from Gallery.
- Open and play a pedal using its persisted sequence and sound profile without re-running image or music generation.
- Retain `PedalResultView` after automatic persistence and provide a completion path to Gallery without a misleading Save action.
- Keep Jam as an explanatory functional placeholder only.

## Navigation Requirements

- Gallery is selected at launch.
- Gallery and Jam own independent typed paths; selecting either root does not clear the other path.
- Photo Inspector is represented only by `GalleryRoute.inspector(UUID)`.
- Root chrome remains outside both root stacks and derives visibility without a duplicate presentation flag.
- Capture never becomes persistent selected state.
- Cancellation before successful processing returns to the pre-Capture destination.
- A successful automatic save retains the result screen until completion or dismissal.
- Result completion selects Gallery and displays the new pedal without relaunch.
- Closing a post-save result does not remove its pedal.
- `CreatePedalIntent` enters central Capture; `PlayLastPedalIntent` requests playback through shared latest selection.

## Persistence Requirements

`PedalStore` becomes the collection persistence boundary outside SwiftUI views. Each collection record has a `PhotoPedal` JSON and processed PNG associated with the same `PhotoPedal.id`; `PhotoPedal.coverFilename` must identify that record cover, not the shared legacy filename.

- Collection writes use temporary JSON and PNG files in the collection directory.
- Before promotion, temporary JSON must decode as `PhotoPedal` with the expected ID and temporary PNG must load as an image.
- Promote both validated temporary files to their final UUID-associated locations only after validation. A failed write must not surface an incomplete record as valid.
- Safe cleanup may remove abandoned temporary artifacts, never a valid final pair or legacy pair.
- Collection loading independently validates each record pair. Missing, unreadable, mismatched, or malformed pairs are invalid and excluded from valid results.
- The foundation storage API owns baseline ordering and latest selection; intents, view models, and views must not duplicate latest-selection logic.
- The current latest-pedal selection remains newest by `createdAt` descending, then `id.uuidString` ascending. A future Library visual order may differ from latest selection and must document that separation explicitly.

## Gallery Requirements

- Load collection data without blocking UI.
- Show `empty` only with no valid record and no failure.
- Show `content` with valid records; if some records are invalid, retain valid content and show a recoverable nonblocking error.
- Show `error` only when no reliable state can load. A valid legacy fallback is reliable state.
- Empty Gallery offers a clear create action.
- Insertion appears after result completion without relaunch.
- Deletion updates storage and UI only after storage deletion succeeds.

## Pedal Detail Requirements

Detail initially shows cover, name, description, current effect, play, stop, and delete. It excludes image-algorithm controls, dithering, manual notes, scale/BPM editing, advanced synth controls, add-to-Jam, original-image editing, and sharing/export.

## Capture Integration Requirements

- Keep the automatic-save boundary: successful `DapViewModel.process(_:)` persistence creates the record before result review.
- Do not add Save UI or a second persistence operation to result completion.
- Preserve duplicate-processing prevention and prevent duplicate persistence/completion actions for one processed result.
- On save failure, preserve the in-memory result and report a controlled retry path; do not navigate as if persistence succeeded.
- Capture/import cancellation before processing succeeds creates no record.

## Jam Foundation Requirements

- Jam is accessible in main navigation and has an understandable empty state.
- Its language describes individual composition, not required multiplayer or technical sequencing.
- It creates no persistent model and starts no playback.

## App Intents Requirements

- `CreatePedalIntent` retains `openAppWhenRun = true` and requests central Capture through `AppIntentRouter`.
- `PlayLastPedalIntent` retains `openAppWhenRun = true` and plays the first valid collection item under shared order. If none exists, it may use valid legacy fallback; if neither exists, it completes without crash or generated replacement.
- Intents do not directly perform capture, processing, storage, sorting, or audio rendering.

## Accessibility Requirements

- Gallery and Jam have clear destination labels.
- The central Capture control has a clear label, hint, adequate touch target, and no inaccessible icon-only representation.
- VoiceOver distinguishes quick play from detail and exposes playback state without color alone.
- Empty, loading, recoverable-error, and blocking-error states are understandable.
- Deletion confirmation/failure feedback are accessible.
- Cards, detail, destinations, and result completion support Dynamic Type and predictable focus order.
- Preserve Reduce Motion. Any custom navigation control gives VoiceOver behavior equivalent to native tabs.

## Reliability Requirements

- Save cannot create accidental duplicates from repeated processing or completion taps.
- One invalid record cannot prevent valid records from loading or playing.
- A transient collection issue with valid records remains recoverable and nonblocking.
- Migration never deletes the legacy pair before collection validation succeeds.
- Starting a different pedal retains `DapSynth` stop-then-start behavior.
- When deleting the currently playing pedal, stop playback first, delete JSON and PNG, update collection, then recalculate latest under shared ordering.
- On deletion failure, retain the item in UI and show an error; do not report successful deletion.
- Closing detail cannot corrupt playback or collection state.

## Data Migration Requirements

On collection initialization, load and validate both legacy `latest-pedal.json` and `latest-pedal.png`.

- Use persisted `PhotoPedal.id` as migrated record identity.
- If collection already contains that ID, do not migrate again.
- Otherwise write and validate the UUID-associated collection pair using normal safe-write rules before treating migration as successful.
- Preserve legacy JSON and PNG unchanged as reversible fallback in all cases. This spec never deletes them.
- Missing/incomplete legacy data creates no collection record.
- If collection is unavailable but legacy is valid, expose valid fallback rather than lose the latest pedal.
- Deleting newest collection item makes next valid ordered item latest. Use legacy fallback only when collection has no valid item.

## Testing Requirements

- Persistence: empty collection, insert, specific recovery, multiple records, ordering and UUID tie-break, delete, safe-write failure, incomplete pairs, temporary cleanup, legacy fallback, idempotent migration, incomplete legacy, partial corruption, and latest after deletion.
- Navigation/coordinator: Gallery initial state, Gallery/Jam switch, Capture nonpersistent state, cancellation return, result retained after auto-save, completion to Gallery, dismissal retaining record, and intent routing.
- Root paths: Gallery/Jam independence, root switching without path loss, Inspector derivation from `galleryPath`, Capture precedence, and external pedal routing into Gallery.
- Gallery transition state: opening, Back, completed/cancelled interactive pop, and root switching do not reload the collection or replace the persisted pedal UUID.
- Gallery state owner: loading, empty, content, recoverable partial error, blocking error, insert, delete, reload, quick play, missing item, and delete failure.
- Playback: play item, play another, delete playing item, absent item, and playback error without losing Gallery state.
- Keep deterministic-generation/serialization coverage focused; do not require byte-for-byte audio tests.

## Device Validation Requirements

Validate manually: main navigation and Capture control, camera, library import, post-save result completion/dismissal, Gallery relaunch recovery, deletion, VoiceOver, Dynamic Type, Reduce Motion, orientation, background/foreground, App Intents through Shortcuts/Siri, and audible playback. Record pass, fail, or not run.

## Technical Constraints

- Use current Swift 6, deployment targets, native APIs, and no dependencies.
- Keep persistence out of SwiftUI views and audio graph/session coordination out of views.
- Do not alter `DapPipeline`, deterministic generation, four-tone cover, Foundation Models metadata boundary, or effect semantics except minimum required integration.
- Do not use fingerprint for identity, cache, deduplication, migration, or new behavior.
- Do not introduce `generatorVersion`, database, cloud sync, or broad legacy renaming/refactoring.
- Prefer localized, reversible changes.

## Acceptance Criteria

- [ ] Gallery and Jam are persistent destinations, with Gallery initially selected.
- [ ] Capture is a central transient action, never a persistent selected destination.
- [ ] Cancelled Capture returns to the prior destination and creates no record.
- [ ] Successful processing automatically persists before `PedalResultView` appears.
- [ ] `PedalResultView` remains after auto-save and has a semantic completion action without Save label.
- [ ] Completing result selects Gallery and reveals the pedal; dismissing does not delete it.
- [ ] Baseline Gallery lists multiple valid pedals by descending `createdAt`, then ascending UUID string.
- [ ] Each pedal has a validated UUID-associated JSON/PNG pair and plays stored music without regeneration.
- [ ] Repeated actions do not duplicate a pedal.
- [ ] Legacy data migrates idempotently, preserves UUID, and is never deleted by migration.
- [ ] Partial corruption does not hide valid records; Gallery distinguishes empty, content, recoverable partial error, and blocking error.
- [ ] Deleting a playing pedal stops playback first; failed deletion leaves it visible and reports error.
- [ ] `PlayLastPedalIntent` uses shared selection; `CreatePedalIntent` opens central Capture.
- [ ] Jam explains individual composition without editing, sequential playback, or collaboration.
- [ ] Music algorithm and cover remain unchanged with no new fingerprint or `generatorVersion` use.
- [ ] Relevant tests, Debug/Release builds, and `git diff --check` pass; unrun device checks are reported pending.

## Test Scenarios

| Area | Scenario | Expected result |
| --- | --- | --- |
| Collection | Valid records with tied dates | UUID string breaks the newest-first foundation tie |
| Collection | One malformed pair among valid pairs | Valid pedals remain visible with recoverable error |
| Write integrity | JSON or PNG validation fails | No valid incomplete collection record appears |
| Migration | Valid legacy UUID already in collection | No duplicate migration record |
| Migration | Valid legacy pair absent from collection | One validated pair added; legacy pair remains |
| Navigation | Processing and auto-save succeed | Result remains visible until completion/dismissal |
| Navigation | Result completion | Capture closes, Gallery selects, new card appears |
| Navigation | Capture cancelled pre-processing | Previous destination remains and no record exists |
| Latest | Newest item deleted | Next valid ordered item becomes latest |
| Playback | Playing item deleted | Playback stops before successful removal |
| Deletion | Storage removal fails | Card remains and accessible error appears |
| Intents | Create and Play Last requests | Existing router reaches Capture and shared latest path |

## Manual Validation Matrix

| Scenario | Expected result | Validation mode |
| --- | --- | --- |
| Launch with no saved pedals | Gallery empty state and create action | Simulator/device |
| Camera and library creation | Existing flow processes, saves, then shows result | Physical device |
| Result completion and dismissal | Both retain pedal; completion selects Gallery | Simulator/device |
| Relaunch and migration | Valid collection or legacy fallback remains available | Simulator/device |
| Quick play, detail, deletion | Controlled playback and collection update | Physical device for audible output |
| VoiceOver, Dynamic Type, Reduce Motion | Controls and state changes remain understandable | Physical device |
| Shortcuts/Siri | Create opens Capture; Play Last uses shared latest | Physical device |

## Allowed Files and Areas

### Expected

- `Dap/Features/Capture/CaptureView.swift`
- `Dap/Features/Capture/CaptureViewModel.swift`
- New focused Gallery/navigation Swift files
- `Dap/Features/Pedal/PedalResultView.swift`
- `Dap/Services/Persistence/PedalStore.swift`
- New focused Gallery, persistence, navigation, and playback tests

### Conditional

- `Dap/Domain/Pedal/Pedal.swift`, only for minimum UUID-associated cover-filename or collection support.
- `Dap/Intents/DapIntents.swift`, only for shared collection/latest integration.
- `Dap/Services/Audio/DapSynth.swift`, only for demonstrated deletion/playback coordination defect.
- `Dap/Features/Capture/CameraPicker.swift`, only for transient presentation/dismiss integration.

### Documentation

- `docs/ARCHITECTURE.md`
- `docs/DATA_MODEL.md`
- `docs/APP_INTENTS.md`
- `docs/TESTING.md`
- `docs/ROADMAP.md`
- `specs/current/navigation-gallery-foundation.md`

## Prohibited Changes

- Jam creation, persistence, reordering, playback, loop, collaboration, iPhone connections, SharePlay, AirDrop, or Jam import/export.
- Video export, cloud sync, dependencies, database adoption, original-image retention, cover sharing, camera controls, filters, or dithering modes.
- Music Generation V2, altered deterministic mapping, fingerprint behavior, or premature `generatorVersion`.
- Broad redesign, legacy cleanup, opportunistic refactors, unrelated renaming, or automatic commits.

## Open Questions

None for this foundation. Automatic persistence, post-save behavior, Gallery as initial destination, no cover sharing, Jam empty state, migration, safe writes, latest selection, and foundation accessibility requirements are resolved. Future visual Library behavior is governed by [Dap Library](pedal-library.md).

## Verification

For implementation work, run focused and full tests using the current scheme and an installed simulator, then build both configurations:

```sh
xcodebuild test -project "Dap.xcodeproj" -scheme "Dap" -destination 'platform=iOS Simulator,name=<installed simulator>'
xcodebuild build -project "Dap.xcodeproj" -scheme "Dap" -configuration Debug
xcodebuild build -project "Dap.xcodeproj" -scheme "Dap" -configuration Release
git diff --check
```

## Implementation Authorization

This Ready specification authorizes the localized Swift, test, project-membership, and directly affected documentation changes required to implement its Gallery and navigation foundation. Run the tests, Debug and Release builds, and `git diff --check` listed above; do not create a commit automatically.
