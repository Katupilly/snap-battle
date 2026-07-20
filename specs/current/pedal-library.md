# Dap Library

Status: Ready
Last updated: 2026-07-17
Feature: Biblioteca de pedais
Platform: iOS 26+
Framework: SwiftUI

## Goal

Define the next Library experience for saved Dap pedals: a dense chronological visual gallery with detail navigation, spatial transition, stable states, and clear technical responsibilities.

This specification is implementation authorization only for the explicitly approved phase and step.

## User Value

Users can quickly recognize, find, and open any saved pedal through a familiar visual history inspired by the iPhone Photos library, adapted to Dap's visual and musical objects.

The Library acts as the visual and sonic history of the user's creations. Covers are the primary interface element, while metadata, playback, effects, and actions stay available without making the grid feel like a list of cards.

## Current Context

The current app already has a Gallery foundation authorized by [Navigation and Gallery Foundation](../current/navigation-gallery-foundation.md). That current spec remains authoritative for app shell navigation, transient Capture, collection persistence, legacy migration, safe writes, deletion, playback coordination, App Intents, Jam placeholder behavior, and latest-pedal selection.

This specification describes the future visual Library iteration and authorizes only the scope explicitly marked for the current implementation phase.

Confirmed product decisions for the future Library:

- The Library follows the spatial model of the iPhone Photos app.
- Visual Library order is `createdAt` ascending.
- Older items appear above newer items.
- Newer items appear below older items.
- Initial entry starts near the end of the collection, close to recent pedals.
- Scrolling upward reveals older items.
- Returning from detail preserves scroll position and active Phase 1 context.
- Do not use inverted `ScrollView`, transforms, or rotation to simulate reverse order.
- Phase 1 excludes favorites, filters, multi-selection, pedalboards, and batch actions.
- Phase 1 reuses the persisted cover asset and may add only a minimal in-memory thumbnail cache; no disk cache or schema change is authorized.

Relevant documents:

- [Architecture](../../docs/ARCHITECTURE.md)
- [Data Model](../../docs/DATA_MODEL.md)
- [Product Specification](../../docs/PRODUCT_SPEC.md)
- [ADR 0001: Deterministic Local Music Generation](../../docs/decisions/0001-deterministic-local-music-generation.md)
- [ADR 0002: Persist Generated Musical Results](../../docs/decisions/0002-persist-generated-musical-results.md)
- [ADR 0003: Foundation Models for Semantic Metadata](../../docs/decisions/0003-foundation-models-for-semantic-metadata.md)

## Product Model

### Pedal

A saved creation combining:

- processed cover image;
- deterministic musical sequence;
- selected effect and sound settings;
- generated or fallback name and description;
- creation date.

### Library

The root destination that displays all saved pedals.

### Cover

The visual asset displayed in the thumbnail and pedal detail. The thumbnail and detail transition must use the same visual source and crop.

### Filter

A future criterion that reduces displayed items without changing the persisted collection. Filters are Phase 2, not Phase 1.

## User Stories

- As a user, I can enter the Library and land near my most recent pedals.
- As a user, I can scroll upward to older pedals and preserve my position when returning from detail.
- As a user, I can tap a thumbnail to open detail with continuity from the thumbnail to the cover.
- As a VoiceOver user, I can understand each pedal, loading state, empty state, error state, unavailable cover, and available detail action.

Future stories:

- As a user, I can filter by all pedals, favorites, and supported effects.
- As a user, I can select multiple pedals for simple supported actions without accidentally navigating.

## Phased Scope

### Phase 1 — Library Foundation

Phase 1 contains only:

- chronological grid;
- grouping by month;
- initial entry near recent items;
- navigation to detail by persisted ID;
- shared-element or native zoom transition from thumbnail;
- standardized detail cover frame;
- scroll preservation when returning from detail;
- loading, empty, error, recoverable partial-error, and unavailable-asset states;
- integration with the existing navigation and bottom bar;
- Reduce Motion and essential accessibility;
- reuse of the existing persisted cover asset;
- downsampled in-memory thumbnails and a minimal in-memory cache, because the current store decodes each persisted PNG into a full `UIImage` before the grid renders it.

Phase 1 must not add favorite persistence, filter controls, selection controls, pedalboard hooks, or batch actions. It must not display nonfunctional controls.

### Phase 2 — Filters And Favorites

Phase 2 adds favorite state and filtering:

- favorite persistence and decode/migration compatibility;
- favorite indicator and accessible favorite action;
- filter model and filter menu;
- all, favorites, and effect filters;
- optional scale filter only if still supported by existing persisted data;
- no-filter-results state;
- transition fallback when an item leaves an active filter.

### Phase 3 — Multi-Selection And Batch Actions

Phase 3 adds:

- multi-selection mode;
- selected state visuals;
- batch favorite/unfavorite if Phase 2 exists;
- batch delete only if safe deletion behavior supports it;
- bottom bar/capture availability while selection is active.

Pedalboard insertion remains out of scope unless a separate current spec authorizes pedalboards.

## Functional Requirements

### Screen Structure

The Library contains:

```text
LibraryView
├── LibraryFloatingHeader
├── ChronologicalPedalGrid
└── CaptureAction availability through global navigation
```

When needed, it also presents:

```text
LibraryView
├── EmptyState
├── RecoverableErrorState
└── UnavailableAssetPlaceholder
```

### Floating Header

The top of the Phase 1 screen may use a floating title/header or independent elements over the grid:

```text
[ Biblioteca ]
```

Phase 1 must not show filter or select controls. In Phase 2, the filter control shows the active filter name:

- Biblioteca
- Favoritos
- Reverb
- Distortion
- scale name, when supported

Use "Biblioteca" as the initial label. Avoid "Todas as fotos" because each item represents more than a photo.

### Grid

The Library uses a dense visual grid:

- 3 columns initially;
- flexible width;
- 1 to 3 pt spacing between cells;
- no permanent text under images;
- no independent card chrome or per-cell shadows;
- image fills the full cell;
- stable aspect ratio and dimensions.

The preferred cell aspect ratio is `1:1`. Cells use `scaledToFill()` with clipping. If the cover pipeline produces a different aspect ratio, the implementation must define a canonical persisted or reproducible crop before shipping.

### Capture Action

Capture remains owned by the global navigation or bottom bar system. Library declares action availability; it must not rebuild the capture button inside the grid.

Capture is visible at the Library root and hidden when:

- a pedal detail is open;
- Jam is active;
- capture/result flow is active.

After Phase 3, it is also hidden while selection mode is active.

The capture action must not change the grid's vertical layout size.

## Sorting And Grouping

### Proposed Chronological Order

The visual Library ordering is:

```swift
createdAt ascending
```

That means:

- older items are earlier in the collection;
- newer items are later in the collection;
- older items appear visually above;
- newer items appear visually below.

On Library entry, the initial position should be near the end of the collection, where recent pedals live. Scroll upward reveals older pedals. Returning from detail preserves the previous scroll position.

The implementation must avoid a visible jump from the top to the end.

### New Items

When a new pedal is saved:

- insert it into the correct chronological section;
- normally place it as the last item;
- scroll to it only when navigation came directly from creation;
- do not automatically displace the user while they are browsing older items.

### Temporal Grouping

Group items by month and year using the user's current calendar and timezone. Do not group by persisted display strings.

Example:

```text
JULHO DE 2026
JUNHO DE 2026
MAIO DE 2026
```

Suggested presentation model:

```swift
struct PedalLibrarySection: Identifiable, Equatable {
    let id: YearMonth
    let title: String
    let items: [StoredPedal]
}
```

Headers are discrete: secondary typography, left aligned, enough spacing to separate periods, and visually quieter than covers.

## Phase 2 Filters

### Required Filters

Phase 2 should support:

```swift
enum PedalLibraryFilter: Equatable {
    case all
    case favorites
    case effect(PedalEffect)
}
```

Initial effects:

- Reverb
- Distortion

Only include "Sem efeito" if the domain has a stable no-effect state.

### Optional Scale Filter

Scale filtering may be included only if the current domain already persists a stable scale:

```swift
case scale(PedalScale)
```

Do not introduce new persistence solely to satisfy scale filtering in this stage.

### Excluded Note Filter

Filtering by individual notes is out of scope for Phase 2 because pedals contain multiple notes, note filtering is musically technical, and it requires enharmonic, octave, and representation decisions.

### Filter Behavior

Applying a filter:

- updates the grid;
- updates the filter control title;
- preserves chronological order;
- removes empty temporal sections;
- may reset scroll to the newest item in the filtered set;
- never alters the persisted collection.

Clearing a filter returns to `.all`, restores the complete Library, and does not modify favorites or other saved data.

### Filter Menu

Use a `Menu`, popover, or equivalent presentation:

```text
Biblioteca
✓ Todos
  Favoritos

Efeito
  Reverb
  Distortion

Escala
  Pentatônica maior
  Pentatônica menor
  Dórico
```

Show the scale section only when supported. Clearly indicate the active filter.

## Pedal Cell

Each cell displays the persisted cover. The image used in the cell must be the same visual source used for the detail transition.

Allowed indicators:

- unavailable or failed asset.

Future indicators after later phases:

- favorite;
- selected;
- currently playing.

Indicators must be discrete and legible over light and dark images.

Do not permanently show:

- pedal name;
- description;
- notes;
- scale;
- date;
- playback controls;
- per-item menu button.

If the cover cannot load:

- show a stable placeholder;
- preserve cell dimensions;
- keep rendering the rest of the Library;
- log only in ways compatible with project privacy rules.

## Navigation And Transition

A simple tap on a cell opens pedal detail using the persisted pedal ID, never an index or transient copy.

The cover is the shared visual element between Library and detail. The transition should:

- start at the exact thumbnail frame;
- expand continuously;
- preserve content and crop;
- end in a standard detail frame;
- reverse to the same cell when returning.

It must not feel like a fade between unrelated images, a new screen followed by a zoom, or an abrupt crop change.

Preferred implementation for iOS 26+ uses native navigation transition APIs, adapted to the current navigation architecture:

```swift
@Namespace private var libraryTransitionNamespace

NavigationLink(value: pedal.id) {
    PedalLibraryCell(pedal: pedal)
        .matchedTransitionSource(
            id: pedal.id,
            in: libraryTransitionNamespace
        )
}
.navigationDestination(for: StoredPedal.ID.self) { pedalID in
    PedalDetailRoute(pedalID: pedalID)
        .navigationTransition(
            .zoom(
                sourceID: pedalID,
                in: libraryTransitionNamespace
            )
        )
}
```

Do not create a second parallel navigation system solely for Library.

### Detail Cover Frame

The detail cover should end in a standard frame:

- screen width minus horizontal margins;
- `1:1` aspect ratio;
- horizontally centered;
- consistent corner radius;
- stable position below navigation chrome.

Initial recommended values:

- horizontal padding: 16 pt;
- aspect ratio: `1:1`;
- corner radius: 20 pt.

### Transition Restrictions

During transition:

- do not remove the source cell;
- do not reorder the collection;
- do not change filter;
- do not regenerate ID;
- do not swap cover asset;
- do not change thumbnail from `scaledToFill` to `scaledToFit`;
- do not reset scroll.

Secondary detail content such as name, description, playback controls, effect, metadata, and actions may appear after the cover transition begins. It must not be part of the primary matched transition.

### Return Behavior

On return:

- the cover collapses to the original cell;
- the grid remains behind detail;
- scroll position is preserved;
- Phase 1 context is preserved;
- grouping is not perceptibly rebuilt;
- the source cell remains visible whenever it still exists in the collection.

After Phase 2, if a detail action causes the item to leave the active filter, such as unfavoriting a pedal while the Library is filtered by favorites, use a safe fallback instead of animating to a nonexistent cell. Update the grid after the transition when possible and avoid crashes, empty intermediate screens, or inconsistent IDs.

## Phase 3 Selection Mode

The "Selecionar" button activates multi-selection.

During selection:

- thumbnails become selectable;
- tap toggles selection;
- detail navigation is disabled;
- capture action disappears;
- header shows selected count;
- cancel exits selection and clears selected IDs.

Initial actions may be limited to:

- favorite;
- unfavorite;
- delete, if safe deletion already exists.

Adding to pedalboards is out of scope.

Selection uses a checkmark, border or overlay, light haptic feedback, and sufficient contrast. Selection must not resize the cell.

## Playback In Library

Phase 1 does not add direct playback controls to grid cells. Detail playback remains governed by the existing foundation behavior.

After a later playback-polish phase, the Library may indicate the currently playing pedal with a small icon, subtle waveform, or overlay.

Direct playback by tapping the thumbnail is not the primary behavior because tap is reserved for navigation. A context menu may later offer playback.

## Context Menu

After later phases, long press may offer:

- Reproduzir;
- Favoritar or Remover dos favoritos;
- Excluir;
- Adicionar ao pedalboard in the future.

The context menu is optional for the first implementation if it adds complexity outside approved scope.

## Interaction States

### Loading

While metadata loads:

- use a discrete indicator;
- do not show an empty grid as final state;
- do not block global navigation;
- do not decode every cover at full resolution during initial load.

### Empty Library

Title:

> Sua biblioteca está vazia

Description:

> Tire uma foto para criar seu primeiro pedal.

Action:

> Criar pedal

The action routes through the global capture model.

### Phase 2 No Filter Results

Title:

> Nenhum pedal encontrado

Contextual descriptions:

> Nenhum pedal está marcado como favorito.

or:

> Nenhum pedal usa Reverb.

Action:

> Limpar filtro

### Error

On loading errors:

- preserve any data that can be displayed;
- offer retry;
- avoid technical messages;
- do not remove persisted items because of a temporary read failure.

## Data Model Changes

Phase 1 does not require persistent schema changes.

Phase 1 uses:

- existing `PhotoPedal.id`;
- existing `PhotoPedal.createdAt`;
- existing UUID-associated persisted PNG cover;
- existing persisted musical data and effect;
- existing collection validation and deletion behavior.

Required before Phase 2:

- define whether favorite state is persisted in `PhotoPedal` or an adjacent user-state record;
- define migration and decode compatibility for favorite state;
- define whether "no effect" exists;
- confirm scale filtering uses the existing persisted `PedalHarmony.scale`;

No persistent schema change may be made without compatibility tests.

## Architecture Impact

### LibraryView

Responsible for:

- screen composition;
- navigation;
- state presentation;
- transition namespace;
- integration with global bottom bar availability.

Not responsible for:

- persistence;
- thumbnail generation;
- audio rendering;
- domain filtering rules.

### Phase 1 Route Contract

The existing shell keeps one `NavigationStack`; Phase 1 adds an explicit typed path to that stack rather than a second navigation system:

```swift
enum AppRoute: Hashable {
    case pedalDetail(UUID)
}
```

The shell/navigation model owns the path and derives presentation from it:

- root Library: `selectedDestination == .gallery && path.isEmpty`;
- pedal detail: `selectedDestination == .gallery && path == [.pedalDetail(id)]`;
- return to Library: pop the detail route so `path.isEmpty`, preserving the same Library view model and scroll state.

Selecting another root clears the path. Capture state remains a separate transient state and has precedence over root/detail presentation. The bottom bar is `.navigation` only for a root, `.hidden` for pedal detail, and keeps the existing capture-flow derivation while Capture is presented. The selected root remains Library after returning from detail.

### Transition Namespace

`ContentView` owns a dedicated `@Namespace` shared by the Library cells and the ID-based detail destination. It is distinct from the shell's existing bottom-bar namespace and is passed through `GalleryView`/`LibraryGridView`. This keeps the namespace in the common ancestor without recreating it per cell.

The native transition is allowed without changing the navigation architecture: keep the existing value-based `NavigationStack`, push `AppRoute.pedalDetail(id)`, attach `.matchedTransitionSource(id:in:)` to the cell cover, and attach `.navigationTransition(.zoom(sourceID:in:))` to the detail destination. A Reduce Motion fallback remains required. The project deployment target is iOS 26.5, which satisfies the API availability; implementation should still retain an availability fallback if the deployment target changes.

### Detail Extraction Boundary

The current `PedalDetailView` is nested in `GalleryView` and receives a transient `StoredPedal` value. Extract it before transition work into a focused detail file (for example `Features/Pedal/PedalDetailView.swift`). The smallest refactor is:

1. move the existing detail body and deletion/playback closures;
2. change the route destination to receive `UUID` only;
3. resolve that ID from the Library model/store at destination time, or show the existing unavailable state if it no longer exists;
4. keep one source of persisted truth and preserve the existing detail actions.

Do not create a second detail model or copy persisted pedal state into navigation state.

### LibraryViewModel

Responsible for:

- loading pedals;
- forming temporal sections;
- deriving Phase 1 scroll targets;
- exposing derived state.

Suggested shape:

```swift
@MainActor
@Observable
final class PedalLibraryViewModel {
    private(set) var sections: [PedalLibrarySection] = []
    private(set) var state: PedalLibraryState = .loading

    func load() async
    func markInitialRecentScrollCompleted()
    func scrollTargetAfterCreation(newPedalID: StoredPedal.ID) -> StoredPedal.ID?
}
```

Final types must follow existing project patterns. Phase 2 may add filter and favorite APIs; Phase 3 may add selection APIs.

### Store Or Repository

Responsible for persistence, loading, deletion, and ID consistency. Phase 2 may add favorite updates after a persistence decision.

### Image Loader

Responsible for thumbnail loading, fallback images, cancellation, and avoiding excess decoding. Phase 1 reuses the persisted cover as the transition/detail source, but adds a small `NSCache`-backed in-memory thumbnail cache with downsampled images for grid cells. The detail path may use the already loaded full cover or a separately decoded detail-sized image; it must preserve the same crop/source semantics. Do not add a disk cache or schema changes.

## Accessibility

### VoiceOver

Each cell exposes a useful label:

> Pedal "Nome", criado em 17 de julho de 2026, favorito, efeito Reverb.

When a name is unavailable:

> Pedal criado em 17 de julho de 2026, efeito Reverb.

Expose actions when applicable:

- Abrir;
- Reproduzir;

Phase 2 may add Favoritar and Remover dos favoritos. Phase 3 may add Selecionar.

### Dynamic Type

The visual grid may keep its column count, but headers, menus, empty states, and contextual bars must support Dynamic Type.

### Reduce Motion

With Reduce Motion enabled:

- avoid broad spatial zoom;
- use a short opacity transition or similarly restrained alternative;
- avoid scale, parallax, and secondary motion;
- preserve a clear relationship between tap and opened item.

The detail cover frame remains the same. Functionality cannot depend on animation.

### Contrast And Targets

Overlays, checkmarks, and indicators must remain legible over light and dark images. Interactive controls must respect minimum practical touch target sizes.

## Performance

- Use lazy rendering, such as `LazyVGrid`, or an equivalent grouped structure.
- Use thumbnails sized for the cell instead of decoding every cover at full resolution on first load.
- Cell identity must be based on `StoredPedal.ID`.
- Do not use index, offset, date alone, image hash, or grid position for identity.
- Phase 2 favorite updates should avoid perceptibly rebuilding the entire Library when the architecture allows localized updates.

## Privacy

If analytics infrastructure already exists, allowed events are limited to:

- Library opened;
- pedal opened;
- empty state shown.

Phase 2 may add a filter-applied event. Phase 3 may add a selection-activated event.

Do not record:

- image content;
- generated name;
- generated description;
- musical notes;
- persisted identifier;
- cover bytes;
- local file path.

Do not add analytics in this stage if no approved infrastructure exists.

## Non-Goals

This implementation must not include:

- pedalboard creation or editing;
- Jam collaboration;
- AirDrop or sharing;
- complex combined filters;
- text search;
- grouping by people, places, or visual content;
- manual sequence editing;
- manual Library reordering;
- iCloud sync;
- bulk deletion unless already safely supported;
- note-level filtering;
- original image editing;
- automatic social publishing.

The spec may prepare interfaces for future features but must not implement them early.

## Initial Code Audit

This audit reflects the code present on 2026-07-17.

### Confirmed

- The saved pedal type is `PhotoPedal` in `Dap/Domain/Pedal/Pedal.swift`.
- `StoredPedal` wraps `PhotoPedal` and a loaded `UIImage` cover in `Dap/Services/Persistence/PedalStore.swift`.
- `PhotoPedal.createdAt` is persisted.
- `PhotoPedal.effect` is persisted as stable `PedalEffect` with `reverb` and `distortion`.
- `PhotoPedal.sequence.harmony.scale` is persisted as `PedalScale`.
- Covers are stored as UUID-associated PNG files and loaded as `UIImage`.
- `PedalStore` owns collection loading, validation, ordering, save, metadata update, deletion, migration, and latest selection.
- Current ordering is descending `createdAt`, then ascending UUID string, per the Ready navigation/gallery foundation spec.
- `GalleryView` now presents the Library's dense three-column `LibraryGridView`.
- `PedalDetailView` is a separate UUID-driven destination file and resolves the current item from `GalleryViewModel`.
- Grid cells open by `AppRoute.pedalDetail(UUID)`; playback and deletion remain available in the existing detail route.
- Current navigation uses one root `NavigationStack` in `ContentView`.
- The bottom bar is owned by `ContextualBottomBar` and configured through `BottomBarPresentation.forNavigation`, which hides it for pedal detail while keeping Library selected.
- Capture is a global/root action, not part of Gallery's internal layout.

### Missing Or Unresolved

- No favorite state exists in the current persisted model.
- No no-effect state exists; only `reverb` and `distortion` are defined.
- No Library filter model exists.
- No temporal section model exists.
- No multi-selection state exists.
- `ThumbnailLoader` exists in `Dap/Services/ImageLoading/ThumbnailLoader.swift`; it downsamples persisted covers, uses an in-memory `NSCache`, propagates cancellation, and has compilable focused tests in `DapTests/ThumbnailLoaderTests.swift`.
- `PedalStore` still loads a full `UIImage` into `StoredPedal` for the existing detail/persistence contract; the Library now resolves the UUID-associated persisted asset through the store and uses `ThumbnailLoader` for grid presentation.
- Native matched-source/zoom transition is implemented for the Library thumbnail and detail cover; Reduce Motion skips the spatial zoom.
- The detail cover uses a square, padded, `scaledToFill` frame with a 20 pt continuous corner radius.
- Current bottom bar does not know about future Gallery selection mode.
- Current Ready spec excludes filters, favorites, and multi-selection; this remains compatible with Phase 1 and becomes relevant only for Phase 2/3.
- Current Ready spec requires newest-first baseline ordering; Phase 1 intentionally separates visual Library order from latest selection.

### Documentation Authority Notes

- `specs/current/navigation-gallery-foundation.md` remains authoritative for foundation behavior and latest selection.
- This spec becomes authoritative for future Library visual order and spatial behavior only after promotion to `current/`.
- `docs/DATA_MODEL.md` does not need a Phase 1 schema update. Phase 2 favorite state would require a separate data-model decision.

### Divergence Table

| Topic | Current foundation behavior | New Library behavior | Real code state | Recommended decision | Migration impact |
| --- | --- | --- | --- | --- | --- |
| Source of authority | Foundation governs navigation, collection persistence, baseline Gallery UI, Jam, Capture, App Intents, latest selection | Library governs future visual grid, spatial order, transition, scroll, and later filters/selection | Foundation implementation exists; Library implementation does not | Keep foundation authoritative for app/persistence contracts; make Library authoritative for future visual behavior once promoted | Documentation-only now |
| Visual ordering | Baseline Gallery lists newest first by `createdAt` descending, UUID ascending tie-break | Phase 1 grid shows oldest above and newest below using `createdAt` ascending | `PedalStore.ordered(_:)` sorts descending and tests assert latest behavior | Separate latest selection from Library visual ordering; Phase 1 should derive visual ascending order for presentation or introduce an explicit store API | Existing records need no migration; ordering tests need updates/additions |
| Latest pedal | First item under current store order is latest | Latest remains newest even if visual grid is ascending | `loadLatest()` uses first collection item | Preserve latest selection as a persistence/app-intent contract | No data migration |
| Layout | Baseline `List` with cards and visible text/actions | Dense 3-column visual grid | `GalleryView` delegates to `LibraryGridView`, which uses `LibraryProjection` and `LazyVGrid` | Phase 1 replaces visual surface only, keeping store/view-model boundaries | No data migration |
| Detail route | Detail by UUID in `NavigationStack` | Detail by persisted ID with shared-element transition | `AppRoute.pedalDetail(UUID)` is pushed in the same root `NavigationStack` and resolved at the shell | Keep typed value-based routing; do not route by index | No data migration |
| Bottom bar | Root bottom bar inserted with `.safeAreaInset(edge: .bottom)` | Capture hidden while detail is open; root context restored on return | `ContextualBottomBar` is attached in root `ContentView`, independent of detail path | Add route/path-aware bottom bar presentation during implementation; avoid overlaying transition destination | No data migration |
| Filters/favorites | Explicitly out of scope | Previously mixed into first Library draft | No favorite field, no filters | Move to Phase 2 | Future schema/migration decision required |
| Multi-selection | Explicitly out of scope | Previously mixed into first Library draft | No selection state | Move to Phase 3 | No Phase 1 migration |
| Thumbnails | Not specified beyond processed cover | Reuse cover; avoid full-size grid cost | `ThumbnailLoader` provides downsample, cancellation, and bounded in-memory `NSCache`; `PedalStore` exposes the UUID-associated asset seam while retaining the existing full-cover `StoredPedal` contract | Use one root-owned loader instance for Library cells; no disk cache or schema migration | No data migration |
| Asset unavailable | Invalid pairs excluded; partial errors possible | Stable per-cell placeholder for unavailable cover | `PedalStore.load(id:)` excludes missing/invalid cover before UI | Phase 1 can keep invalid-pair exclusion and add placeholder only for runtime cell load failure if image loading moves out of store | No data migration |
| Deletion | Supported with safe deletion and playing-item stop | Not a Phase 1 grid batch action; detail deletion may remain | Detail and swipe delete exist | Preserve detail deletion if retained from foundation; do not add batch delete | No data migration |
| Jam/Capture | Persistent Gallery/Jam roots and transient Capture | Library integrates with existing navigation/bottom bar | `AppNavigationModel` and `BottomBarPresentation` implement this | Do not move these contracts into visual Library spec except as integration requirements | No data migration |

### Foundation Requirement Disposition

| Foundation requirement area | Disposition | Notes |
| --- | --- | --- |
| Persistent Gallery and Jam roots | Continue valid | Do not remove; Library is still the Gallery root's visual content |
| Transient Capture action and cancellation return | Continue valid | Phase 1 must integrate with existing capture model |
| Automatic save before result review | Continue valid | Library must consume saved records, not save again |
| Result completion/dismiss keeps saved pedal | Continue valid | New Library should reveal new pedal after completion |
| Collection persistence, UUID JSON/PNG, validation, migration | Continue valid | Incorporate by reference; do not reopen in Phase 1 |
| Safe writes and invalid-pair recovery | Continue valid | Supports Library loading/error states |
| Latest-pedal selection and `PlayLastPedalIntent` | Continue valid | Must be separated from ascending visual order |
| Baseline newest-first Gallery list/card UI | Replaced by Library Phase 1 | Only visual behavior is superseded |
| Quick play from baseline card | Replaced or deferred for grid | Detail playback remains valid; grid playback polish is later |
| Deletion from Gallery/detail | Continue valid where already implemented | Phase 1 must not add batch actions |
| Jam placeholder behavior | Continue valid | Not owned by Library visual spec |
| App Intent routing | Continue valid | Do not duplicate routing/sorting in Library views |
| Accessibility for destination labels, states, deletion feedback | Incorporate | Phase 1 adds grid/detail transition accessibility |
| Reduce Motion preservation | Incorporate | Phase 1 must provide transition fallback |
| Prohibition on filters/favorites/multi-selection in foundation | Superseded only by later phases | Phase 1 still follows the prohibition |

### Native Transition Audit

| Question | Audit result |
| --- | --- |
| Where should the namespace live? | In the Library/Gallery root view that owns both cell sources and `.navigationDestination`, likely `GalleryView` after it becomes the Library container. Keeping it below `ContentView` avoids mixing with the bottom-bar namespace and keeps source/destination in one navigation subtree. |
| Does the destination use a persisted ID? | Yes. `AppRoute.pedalDetail(UUID)` carries only `PhotoPedal.id`; the destination resolves the current item from `GalleryViewModel`. |
| Does the bottom bar interfere? | Potentially. The root bottom bar is inserted with `safeAreaInset` in `ContentView` and currently remains while detail is pushed. Phase 1 should make bottom bar presentation route-aware so Capture is hidden on detail and the transition destination is not visually competing with the bar. |
| Can the detail receive the standardized frame? | Yes. Current `PedalDetailView` is local to `GalleryView` and shows `Image(uiImage:)` inside a `ScrollView`. It can be extracted or refactored to use `scaledToFill`, `aspectRatio(1, contentMode: .fill)`, horizontal padding, and a 20 pt corner radius. |
| Is swipe back preserved? | It should be preserved if Phase 1 keeps value-based `NavigationStack` navigation and applies native `.navigationTransition(.zoom(...))` to the destination instead of building a custom overlay navigation. |
| Which mutations can remove the source cell? | Phase 1: deletion can remove the source item; reload after capture or metadata update can rebuild the collection. Phase 2: filters/favorites can remove source cells. Phase 3: batch delete can remove several sources. Phase 1 should avoid deleting/reordering during the transition and use a fallback unavailable-detail state if the item disappears. |
| Is `matchedTransitionSource`/`.zoom` architecture-compatible? | Architecturally yes, because source cells and destination are already in the same `NavigationStack` route tree. Implementation must confirm exact API availability against the project deployment target and provide a Reduce Motion/fallback transition if needed. |

### Initial Scroll Position Audit

| Concern | Phase 1 recommendation |
| --- | --- |
| Strategy | Use `ScrollPosition` with `idType: UUID` and stable persisted IDs. Scroll to the newest pedal ID with `anchor: .bottom`; retain `ScrollViewReader` only as an SDK-compatibility fallback. |
| Timing | Execute initial scroll after non-empty sections are loaded and laid out. Use a one-shot state flag so reloads do not repeatedly force the user to the bottom. |
| Visible jump prevention | Prefer setting the scroll position before or during first visible content presentation. If needed, keep a loading/settling state until the one-shot initial scroll completes. Do not animate the first positioning jump. |
| Empty Library | Do not call `scrollTo`; show the empty state and global create action. |
| New pedal after creation | If the Library appears because result completion created a new pedal, scroll to that pedal or the bottom sentinel once. Do not auto-scroll for background reloads while the user is browsing older items. |
| Return from detail | Preserve the same Library view/model instance and do not reset the one-shot initial-scroll flag. Avoid state changes that rebuild sections unnecessarily. |
| Monthly sections | Give sections and items stable IDs. A bottom sentinel avoids needing to know the last item of the last section, but scrolling to the new pedal ID is better after creation. |
| SDK audit | The current iOS 26.5 SDK exposes `ScrollPosition.init(idType:)`, `scrollTo(id:anchor:)`, and `View.scrollPosition(_:)`; the deployment target is iOS 26.5, so the preferred API is viable. |
| No inverted scroll | Use natural ascending data and normal `ScrollView`; do not rotate, scale, invert, or reverse the coordinate system. |

## Acceptance Criteria

### Phase 1 — Library Foundation

- [ ] The Library uses a three-column grid.
- [ ] Cells keep stable dimensions.
- [ ] Older items appear above newer items.
- [ ] Newer items appear below older items.
- [ ] Initial entry positions the user near recent items.
- [ ] New pedals appear at the end of the collection.
- [ ] The grid is grouped by month and year.
- [ ] Empty groups are not displayed.
- [ ] The cover starts from the tapped cell.
- [ ] Expansion occurs without abrupt fade between assets.
- [ ] Crop remains consistent.
- [ ] The final frame is standardized.
- [ ] Secondary content does not compete with the start of the animation.
- [ ] Return collapses the cover to the correct cell.
- [ ] Swipe back remains functional.
- [ ] Library scroll is preserved.
- [ ] Reduce Motion uses an appropriate alternative.
- [ ] Cells have useful VoiceOver labels.
- [ ] Indicators have sufficient contrast.
- [ ] Empty, loading, error, partial-error, and unavailable-asset states respond to Dynamic Type.
- [ ] Interactive areas have adequate target size.
- [ ] The interface works with Reduce Motion.
- [ ] One thumbnail failure does not break the grid.
- [ ] IDs stay stable after updates.
- [ ] Returning from detail does not reset Library state.
- [ ] Capture action is visible at Library root and hidden while detail/capture/Jam contexts require it.
- [ ] No filter, favorite, selection, pedalboard, or batch-action control is displayed.
- [ ] Debug build passes.
- [ ] Release build passes.
- [ ] Existing tests remain green.

### Phase 2 — Filters And Favorites

- [ ] Users can view all pedals.
- [ ] Users can mark and unmark favorites after a persistence decision.
- [ ] Users can filter favorites.
- [ ] Users can filter by supported effect.
- [ ] Optional scale filter appears only if approved.
- [ ] The filter title reflects the active state.
- [ ] Filtering does not alter the persisted collection.
- [ ] No-result filtered state is distinct from empty Library.
- [ ] Users can clear the filter.
- [ ] Active filter is preserved when returning from detail.
- [ ] Transition does not break when the item leaves the active filter.
- [ ] Favorite changes do not cause unintended reordering.

### Phase 3 — Multi-Selection And Batch Actions

- [ ] Select activates multi-selection.
- [ ] Tap stops opening detail during selection.
- [ ] The cell does not resize when selected.
- [ ] Selected count is communicated.
- [ ] Cancel clears selection.
- [ ] Capture action disappears during selection.
- [ ] Batch actions only appear when their behavior is implemented and accessible.

## Required Tests

Phase 1 unit tests:

- month/year grouping;
- `createdAt` ordering;
- empty section removal;
- empty state;
- ID stability after update;
- initial recent scroll target derivation;
- new-pedal scroll target derivation.

Phase 1 UI or integration tests:

- open pedal from cell;
- return preserving position;
- Reduce Motion;
- empty Library;
- large collection;
- unavailable cover.

Visual manual validation is required for the spatial transition because automated tests are unlikely to fully evaluate continuity.

Phase 2 tests:

- favorites filter;
- effect filter;
- optional scale filter if shipped;
- no-filter-results state;
- open item with active filter;
- change favorite in detail;
- item removed from active filter.

Phase 3 tests:

- activate and cancel selection;
- selection count accessibility;
- batch action availability;
- capture hidden during selection.

## Device Validation

Validate on simulator or device:

- Library root and capture action;
- long collection initial position;
- camera and photo library creation;
- result completion into Library;
- detail open and return transition;
- deletion if included;
- VoiceOver;
- Dynamic Type;
- Reduce Motion;
- orientation;
- background/foreground.

Phase 2 additionally validates filter menu, favorite state, and no-results state. Phase 3 additionally validates selection mode and any batch action.

## Documentation Updates

When implementation is authorized and completed, update:

- [Data Model](../../docs/DATA_MODEL.md) only if a later phase adds favorite state or persistent thumbnail/cache ownership;
- [Architecture](../../docs/ARCHITECTURE.md) for Library view model, image loader, and transition responsibilities;
- [Product Specification](../../docs/PRODUCT_SPEC.md) for the Library experience;
- [Testing](../../docs/TESTING.md) for grouping, scroll, transition, and accessibility coverage. Add filters and selection only when Phase 2 or Phase 3 ships.

## Resolved Phase 1 Decisions

- Presentation derives `createdAt`-ascending visual order in `LibraryViewModel`/a Library projection. `PedalStore` keeps its global newest-first order and `loadLatest()` contract.
- Route state is an explicit typed path: empty path is the selected Library root; `.pedalDetail(UUID)` is detail; popping it returns to Library.
- The detail is extracted before transition implementation and resolves a persisted ID without duplicating persisted state.
- `LibraryView` owns the transition namespace; the bottom-bar namespace remains shell-owned and separate.
- Native `.matchedTransitionSource` plus `.navigationTransition(.zoom)` is compatible with the current single `NavigationStack` and iOS 26.5 deployment target, with Reduce Motion fallback.
- Full-resolution cover loading is confirmed in `PedalStore.load(id:)` and `loadLegacy()`. Phase 1 therefore includes downsampled grid thumbnails and a minimal memory-only cache; no disk cache or schema change.
- The product label is `Biblioteca`; new presentation types use `Library`, while existing `Gallery` names remain only for compatibility during the refactor.
- Tests must separately assert visual ascending order, latest selection, month grouping, initial recent-end target, and scroll preservation after detail return.

Deferred questions about favorites, favorite migration, optional scale filtering, and filter-removal transition fallback remain Phase 2 questions and do not block Phase 1.

## Implementation Plan

Implementation is authorized only for the current phase and step explicitly selected by the implementation request.

Phase 1 implementation order is:

1. Separate Library types and presentation projection: sections, ascending order, stable IDs, and scroll intents.
2. Extract or stabilize ID-resolved detail without changing persistence.
3. Implement the grouped three-column grid and all Phase 1 states.
4. Implement initial end positioning and scroll preservation, including async reload and creation return.
5. Integrate the explicit route/path with bottom-bar presentation.
6. Add the shared-element/native zoom transition and standardized detail frame.
7. Complete accessibility, Reduce Motion, Dynamic Type, and state polish.
8. Add focused tests, UI/manual validation, and Debug/Release verification.

Phase 2 implements filters and favorites only after the favorite persistence decision is resolved. Phase 3 implements selection and batch actions only after Phase 2 or a separate action spec authorizes the relevant behavior.

## Definition Of Done

- The Library presents pedals in a chronological grid.
- Recent items are available near the bottom on entry.
- Opening detail uses a continuous spatial transition.
- Detail has a standardized cover frame.
- Returning preserves scroll.
- Accessibility states are covered.
- Tests and builds pass.
- No unrelated scope is changed.
- No automatic commit is made.
