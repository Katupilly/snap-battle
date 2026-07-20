## Dap Pedalboard Phase 2 Foundation

Status: Ready
Last updated: 2026-07-17
Feature: Pedalboard foundation
Platform: iOS 26+
Framework: SwiftUI

## Context

Dap already persists multiple saved pedals, exposes them through the Library, opens detail by persisted UUID, and replays the stored musical result without regenerating it. The app also has a persistent Jam root, but that root is still a placeholder with no domain model, persistence, or playback of ordered saved pedals.

The current sources of truth for existing behavior remain:

- [Navigation and Gallery Foundation](navigation-gallery-foundation.md)
- [Dap Library](pedal-library.md)
- [Architecture](../../docs/ARCHITECTURE.md)
- [Data Model](../../docs/DATA_MODEL.md)
- [Audio System](../../docs/AUDIO_SYSTEM.md)
- [App Intents](../../docs/APP_INTENTS.md)
- [ADR 0001: Deterministic Local Music Generation](../../docs/decisions/0001-deterministic-local-music-generation.md)
- [ADR 0002: Persist Generated Musical Results](../../docs/decisions/0002-persist-generated-musical-results.md)

This specification authorizes only the minimum local Pedalboard foundation. It does not authorize collaboration, sharing, cloud sync, or advanced music editing.

## Problem

The app currently stops at the level of individual saved pedals. A person can save, browse, reopen, and replay one pedal, but cannot create and persist a simple composition made from an ordered sequence of saved pedals.

Without a first-class Pedalboard object:

- Jam cannot evolve beyond placeholder UI;
- users cannot reuse their saved pedals as one simple composition;
- future board playback, sharing, and collaboration lack a stable persistence and domain boundary.

## Objective

Introduce the smallest useful Pedalboard vertical slice that proves the central object locally and safely:

- create a pedalboard;
- add saved Library pedals by stable reference;
- reorder and remove them;
- play them sequentially;
- stop playback;
- save and reopen the pedalboard.

The user must not need musical knowledge to use this feature.

## Primary Experience

1. The user opens `Jam`.
2. If no pedalboards exist, the app shows an empty state and an action to create one.
3. The user creates a new pedalboard with a default editable name.
4. The user adds one or more previously saved pedals from the Library.
5. The pedalboard detail shows the ordered sequence of added pedals.
6. The user can move pedals up or down, remove them, or add the same saved pedal more than once.
7. Pressing Play reproduces the saved pedals in order.
8. Pressing Stop cancels board playback immediately.
9. Relaunching the app shows the saved pedalboard again with the same ordered references.

## Scope

Phase 2 foundation includes only:

- pedalboard domain model;
- isolated pedalboard persistence store;
- pedalboard list screen under the current Jam root;
- empty state for no pedalboards;
- pedalboard detail screen;
- default editable pedalboard name;
- add-from-Library flow using existing saved pedals;
- ordered list of pedal references;
- remove pedal from pedalboard;
- reorder pedal references;
- sequential playback of pedal references;
- explicit Play and Stop controls;
- visual indication of the pedal currently playing;
- save, load, reopen, and delete pedalboards;
- accessible reorder actions that do not rely only on drag.

## Out Of Scope

This phase must not include:

- Jam collaboration;
- SharePlay;
- MultipeerConnectivity;
- AirDrop;
- simultaneous editing;
- cloud sync;
- accounts;
- public sharing;
- video export;
- simultaneous effect chains;
- manual note editing;
- advanced music controls;
- global board BPM editing unless a follow-up spec authorizes it;
- Siri/App Intents for pedalboards, beyond keeping architecture ready for them;
- migration of `StoredPedal.image` or `PhotoPedal` schema;
- broad profiling without evidence of a problem.

## Scroll Comment Triage Note

PR #1 left one automated review comment on `Dap/Features/Library/LibraryGridView.swift` about `scrollTargetLayout()` placement relative to `scrollPosition.scrollTo(id:)`.

Triage result for this round: `Non-blocking debt`.

- File and line referenced by the PR comment: `Dap/Features/Library/LibraryGridView.swift`, line 154 in the merged PR commit.
- Alleged behavior: the initial Library scroll target may fail to resolve the most recent cell UUID because the grid cell targets live inside `LazyVGrid` while `.scrollTargetLayout()` is applied at the outer container.
- Relevant current concerns: initial position near recent items, `scrollPosition`, `scrollTargetLayout`, reload-driven view recreation, tab switch back to Library, and collections with tied dates.
- Not currently evidenced as a confirmed functional regression in this round because no runtime reproduction was completed here.
- Do not modify Library code for this comment in this round unless a concrete jump, wrong return position, wrong target, or unstable identity is reproduced.

## Domain Model

### Pedalboard

The minimum persisted object is:

```swift
struct Pedalboard: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var entries: [PedalboardEntry]
}

struct PedalboardEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let pedalID: StoredPedal.ID
}
```

### Identity

- `Pedalboard.id` is a random UUID created once.
- `PedalboardEntry.id` is a random UUID created once per insertion.
- `PedalboardEntry.pedalID` references an existing saved pedal by `StoredPedal.ID`.

`PedalboardEntry.id` exists so the same saved pedal can appear more than once in the same board without losing reorder and removal stability.

### Name

- A newly created board must have a default user-visible name.
- Initial recommendation: `Novo pedalboard`.
- The name must be editable from the board detail screen.
- Empty or whitespace-only edits must normalize back to the default name or be rejected by the save path. Final implementation should choose one rule and test it explicitly.

### Dates

- `createdAt` is set on creation.
- `updatedAt` is refreshed on any persisted structural or naming change.
- Playback alone does not update `updatedAt`.

### Ordered Collection Of References

- `entries` is the playback and display order.
- Reordering changes only `entries` order and `updatedAt`.
- The board does not own or duplicate the referenced pedal payload.

### Duplicate Pedals In One Board

- The same `StoredPedal.ID` may appear multiple times in one board.
- Each insertion becomes a distinct `PedalboardEntry`.
- Removing one duplicate must not remove other duplicates.

### Missing Referenced Pedals

If a referenced saved pedal is later deleted from the Library:

- keep the `PedalboardEntry` persisted;
- surface it as a missing pedal in UI;
- skip it during sequential playback;
- allow the user to remove it manually;
- do not silently rewrite the board during load.

This keeps the board stable and debuggable without deleting user intent behind the scenes.

### Explicit Non-Decision

This phase does not use snapshots, duplicated `PhotoPedal` payloads, duplicated images, duplicated audio buffers, or copied metadata inside the board model.

## Persistence

### Store Boundary

Add a new isolated persistence boundary separate from `PedalStore`:

```swift
struct PedalboardStore {
    func loadCollection() -> PedalboardStoreLoadResult
    func load(id: UUID) throws -> Pedalboard
    func save(_ board: Pedalboard) throws
    func delete(id: UUID) throws
}
```

`PedalStore` remains the source of truth for saved pedals. `PedalboardStore` owns only boards.

### Folder And Format

- Folder: `Application Support/pedalboards/`
- One file per board: `<board-id>.json`
- No sidecar image or audio files in Phase 2 foundation.

### Initial Schema

Use an explicit schema envelope from the start:

```swift
struct PedalboardDocument: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let board: Pedalboard
}
```

Initial value:

- `schemaVersion == 1`

### Loading

- Load all valid board documents from the pedalboard directory.
- Decode each board independently.
- One corrupted file must not block valid boards.
- Return a partial-error load result when some boards fail and others succeed.
- Return a blocking error only when no reliable board state can load and at least one file failed.

### Saving

- Use temporary-file write, validation, then promotion to the final URL.
- The promoted file must decode successfully as `PedalboardDocument` before completion.
- The decoded board ID must match the intended file UUID.

### Deletion

- Delete only the targeted board document.
- Do not cascade into `PedalStore`.
- Deleting a board must not delete referenced pedals.

### Corruption Tolerance

- Invalid board files stay excluded from valid loaded results.
- Valid board files remain visible.
- The UI must surface a recoverable non-blocking issue if some boards fail.

### Atomicity Minimum

Match the current pedal persistence safety style at the minimum practical level:

- write temporary file;
- validate decode and ID;
- move to final path atomically or as the platform-equivalent best effort;
- do not surface incomplete board files as valid.

### Separation From Pedal Persistence

- `PedalStore` still owns pedal JSON/PNG pairs, latest selection, and pedal deletion.
- `PedalboardStore` must not reuse the pedal folder or change `StoredPedal` schema.
- Board loading resolves pedal references through `PedalStore` only when needed by the UI or playback path.

## Playback State Machine

### Goal

Sequential playback must use the existing saved pedal payload and the existing synth seam without regenerating music.

### Coordinator

Add a dedicated coordinator separate from SwiftUI views and separate from `GalleryViewModel`.

Suggested shape:

```swift
@MainActor
final class PedalboardPlaybackCoordinator {
    enum State: Equatable {
        case stopped
        case playing(boardID: UUID, entryIndex: Int)
    }

    func play(board: Pedalboard) async
    func stop()
}
```

The final API may differ, but the architectural role must remain separate from the view.

### Playback Order

- Playback order is `entries` from index `0` to `entries.count - 1`.
- No shuffle, loop, or branch behavior in this phase.

### When A Pedal Ends

For Phase 2 foundation, one pedal ends when its rendered sequence duration finishes under the current saved sequence BPM and step count.

Because `DapSynth` currently renders one sequence at a time and does not expose a completion callback, implementation may add the smallest correct seam to determine sequence duration or completion. That seam must not move audio graph ownership into SwiftUI.

Step 2 implementation resolves this by centralizing the synth's sample-aligned duration formula and injecting a cancellable scheduler into the coordinator. The duration uses the fixed rendered step count (`16`) and saved BPM; rests, gate, and note count do not shorten playback because the synth renders every step.

### Gap Between Pedals

- No intentional extra gap is required in this phase.
- If a tiny engine restart gap exists because of the current synth architecture, it is acceptable for Phase 2 foundation.
- Do not implement crossfade or overlap.

### Play

- Play from the first entry every time in Phase 2 foundation.
- If the board is empty, Play must do nothing or remain disabled. Pick one explicit behavior and test it.
- If another board is already playing, starting a new play request must stop the previous playback first.

### Stop

- Stop must immediately cancel any in-flight sequential playback task.
- Stop must call the underlying player stop path.
- Stop resets current playback state to stopped.

### Replay

- Pressing Play after the board finishes starts again from the first entry.
- Pressing Play while already playing should restart from the first entry or be ignored; choose one behavior, document it in code, and test it.

Step 2 chooses restart semantics: a new Play cancels the prior scheduled progression, stops the underlying player, invalidates late callbacks, and starts from the first resolvable entry.

### Missing Pedals During Playback

- If an entry references a missing pedal, skip it.
- Continue to the next entry.
- The currently playing indicator must never point to a missing entry as if playback succeeded.

Step 2 differentiates normal absence from structural load failure: a missing record is skipped and exposed as unavailable entry information, while corrupt or incompatible pedal data fails the board playback without mutating the board.

### Existing Synth Reuse

- Reuse the current `PedalPlaying` seam and `DapSynth` behavior for actual per-pedal rendering.
- Do not duplicate sequence generation.
- Do not move engine creation into a view.

### Prevent Multiple Concurrent Playbacks

- Only one board playback may be active at a time.
- One board playback must not overlap with another board playback.
- Implementation should also stop an active board before allowing independent quick-play from the same coordinator-owned player, or keep those surfaces isolated. Final code must avoid simultaneous conflicting playback paths.

### Lifecycle And Interruptions

- Preserve the current synth interruption stop behavior.
- Board playback must transition back to stopped if the underlying player stops because of interruption.
- Automatic resume after interruption is out of scope.

## Interface Flows

### Entry Point

The existing Jam root becomes the entry point for pedalboards.

Phase 2 foundation replaces the placeholder with a functional minimum structure:

```text
JamRootView
├── PedalboardsView
│   ├── EmptyState
│   └── PedalboardList
└── PedalboardDetailView
```

### Pedalboard List

Requirements:

- show all valid pedalboards;
- sort by `updatedAt` descending unless another order is explicitly chosen and tested;
- provide an action to create a new board;
- open board detail by persisted board ID.

### Empty State

Title:

> Sua Jam está vazia

Description:

> Crie um pedalboard e adicione pedais salvos para tocar uma sequência simples.

Action:

> Criar pedalboard

### Pedalboard Detail

Requirements:

- show editable board name;
- show ordered pedal entries;
- show each entry using existing pedal cover and name when available;
- show a stable missing-pedal row when unavailable;
- support add, remove, reorder, Play, and Stop;
- indicate the currently playing entry.

### Add From Library

The minimum add flow may use a sheet or push flow that lists saved pedals from the existing Library source of truth.

Requirements:

- read from the current saved pedal collection;
- insert selected pedals at the end of the current board;
- allow choosing the same saved pedal multiple times across repeated insertions;
- do not duplicate pedal persistence payloads.

### Reordering

- Reordering must be possible with touch interaction.
- Reordering must also be possible through accessible explicit move actions.
- The final ordering must persist after relaunch.

### Removing

- Removing an entry updates only the board.
- Removing an entry does not delete the referenced saved pedal.

### Playback Indicator

- While stopped, no entry shows as currently playing.
- While playing, exactly one entry at most shows the current-play state.
- Missing entries must not appear as actively playing.

## Accessibility

### Reorder Accessibility

Do not rely only on drag.

The detail screen must provide accessible move actions such as:

- `Mover para cima`
- `Mover para baixo`

These actions must be available wherever a drag-only reorder would otherwise be the only path.

### Pedal Labels

Each available entry should expose:

> Pedal "Nome", posição 2 de 5

If missing:

> Pedal indisponível, posição 2 de 5

### Playback State

- Play and Stop must have clear labels and hints.
- The currently playing entry must be announced without relying on color alone.
- Missing pedals must have a distinct accessible description.

### Reduce Motion

- Reorder feedback and playback indication must not depend on large motion.
- If animations exist, they must remain understandable with Reduce Motion enabled.

## Debug And Test Strategy

### Fixtures

Add focused deterministic fixtures for:

- empty board;
- board with one pedal;
- board with multiple pedals;
- board with the same pedal duplicated;
- board with one missing pedal reference;
- board with one corrupted persisted board document;
- board after reorder.

Do not add large datasets beyond what is already justified for Library debug validation.

### Required Unit Tests

- `Pedalboard` create/update semantics;
- duplicate entries retain distinct `PedalboardEntry.id` values;
- save/load round trip;
- delete board;
- corruption isolation;
- missing pedal reference remains present in the loaded board;
- reorder persistence;
- default-name normalization rule.

### Required Playback Tests

- play empty board behavior;
- play one pedal;
- play multiple pedals in order;
- stop cancels the sequence;
- missing pedal is skipped;
- concurrent play requests do not produce simultaneous playback state.

### Required UI Or Integration Tests

- create a board from empty state;
- open board detail;
- add saved pedal;
- remove entry;
- reorder entry;
- relaunch and reopen saved board;
- currently playing indicator updates.

## Risks

- `DapSynth` is currently single-pedal oriented and does not expose natural completion callbacks.
- Board playback may need a minimal new seam for sequence duration or completion notification.
- The current app has two playback surfaces, Gallery detail and future board playback, so concurrency policy must be explicit.
- Missing-pedal handling can become confusing if the UI does not clearly distinguish unavailable entries from playable ones.
- Existing documentation still contains some legacy wording around latest-pedal storage and `coverFilename`; implementation must continue to trust real code behavior first.

## Open Decisions

- Final user-facing naming between `Jam`, `Pedalboard`, and any mixed terminology.
- Exact rule for Play while already playing: restart or ignore.
- Exact validation rule for blank board names: normalize or reject.
- Whether board list sort order should be `updatedAt` descending or `createdAt` descending.
- Whether the first add flow should allow single selection only or repeated single inserts; multiple selection is not required for this phase.

These decisions do not block the domain and persistence foundation, but the implementation must resolve them before UI shipping.

## Acceptance Criteria

- [ ] The Jam root no longer shows only placeholder content.
- [ ] The app can create an empty pedalboard.
- [ ] A newly created pedalboard has a default user-visible name.
- [ ] The user can edit the pedalboard name.
- [ ] The user can add saved Library pedals to a pedalboard.
- [ ] The same saved pedal can be added more than once.
- [ ] The pedalboard preserves a stable ordered sequence of references.
- [ ] The user can reorder pedalboard entries.
- [ ] The user can remove a pedalboard entry without deleting the referenced saved pedal.
- [ ] The user can play the board from the start.
- [ ] The user can stop playback explicitly.
- [ ] Playback advances in entry order.
- [ ] Missing referenced pedals do not crash the board and are skipped during playback.
- [ ] The currently playing entry is visually and accessibly indicated.
- [ ] The user can close and relaunch the app and reopen the same pedalboard.
- [ ] Pedalboard persistence is isolated from `PedalStore`.
- [ ] `PhotoPedal` persistence schema is unchanged.
- [ ] Focused board domain, persistence, and playback tests pass.
- [ ] `git diff --check` passes.

## Implementation Plan

### Step 1 — Domain And Persistence

Implement first:

- `Pedalboard`;
- `PedalboardEntry`;
- board document schema;
- `PedalboardStore`;
- focused persistence tests.

This step is the foundation for every later step.

### Step 2 — Sequential Playback

Implement second:

- `PedalboardPlaybackCoordinator`;
- Play and Stop behavior;
- current entry state;
- missing-entry skip behavior;
- focused playback tests.

This step depends on Step 1.

### Step 3 — Functional Interface

Implement third:

- board list screen under Jam;
- board detail screen;
- create flow;
- add-from-Library flow;
- remove and reorder;
- currently playing indication.

This step depends on Steps 1 and 2.

### Step 4 — Stabilization

Implement fourth:

- accessibility polish;
- missing-data and corruption states;
- lifecycle verification;
- focused build/test validation;
- any documentation updates caused directly by implementation.

This step depends on Steps 1 through 3.

## Definition Of Done

- The project has a persisted `Pedalboard` model.
- The Jam root exposes a functional minimum board flow.
- Boards reference saved pedals by stable ID instead of copying payloads.
- A board can be created, named, populated, reordered, saved, reopened, played, and stopped.
- Missing references remain safe and understandable.
- Audio graph ownership stays outside SwiftUI views.
- Deterministic pedal generation remains unchanged.
- No out-of-scope collaboration, sharing, cloud, or advanced music editing ships in this phase.
