# Contextual Bottom Bar Morph

Status: Ready
Last updated: 2026-07-17

## Goal

Replace the current custom bottom navigation bar with one persistent contextual bottom bar owned by the app shell. The bar presents root navigation, screen-specific actions, or a hidden state while preserving the existing capture presentation mechanism.

The transition must feel like two persistent physical pieces reorganizing themselves. It must not be implemented as one unrelated bar disappearing while another unrelated bar cross-fades in.

## User Value

People should keep a stable spatial anchor at the bottom of Photo Pedal. Root screens expose navigation and capture. Creation result review exposes `Retake` and `Save Pedal`. Immersive camera UI hides the bar. Playback preview remains close to the pedal content where the user can evaluate sound before saving/completing the flow.

## Current Context

Implementation is the source of truth for this specification.

### App Shell And Entry Point

- `snap_battleApp` is the app entry point and instantiates `ContentView` in `snap-battle/snap_battleApp.swift:10-14`.
- `ContentView` in `snap-battle/Features/Capture/CaptureView.swift:10-73` is the current app shell even though it lives in the Capture feature folder.
- `ContentView` owns `AppNavigationModel` and `GalleryViewModel` at `snap-battle/Features/Capture/CaptureView.swift:11-12`.
- The shell uses one root `NavigationStack` at `snap-battle/Features/Capture/CaptureView.swift:19`.
- The shell switches root content with `navigation.selectedDestination` at `snap-battle/Features/Capture/CaptureView.swift:21-24`.
- The current bottom bar is `MainNavigationBar`, inserted with `.safeAreaInset(edge: .bottom)` at `snap-battle/Features/Capture/CaptureView.swift:26-28`.

There is no native `TabView`, no `NavigationPath`, and no independent root history today.

### Root Destinations

The real root destinations in code are:

- `.gallery`, selected by default in `snap-battle/Features/Navigation/AppNavigationModel.swift:6-8`;
- `.jam`, also present in `AppNavigationModel.Destination`, but currently only a placeholder rendered as `JamPlaceholderView` in `snap-battle/Features/Gallery/GalleryView.swift:170-175`.

The first implementation of this bar includes the current Gallery root and the existing Jam root placeholder in the navigation piece. Jam collaboration and an active Jam session are explicitly out of scope for this implementation. The navigation piece must support a variable destination collection so future roots or real Jam behavior can be added later by a separate approved spec without changing the morph mechanism.

This spec uses `Gallery` only as the current implemented product vocabulary from code (`GalleryView`, `navigationTitle("Gallery")`, and current empty-state copy in `snap-battle/Features/Gallery/GalleryView.swift:11` and `snap-battle/Features/Gallery/GalleryView.swift:45`). It does not rename the product surface or introduce `Home`, `Library`, `Pedals`, `Profile`, or `Pedalboards` as final labels.

### Capture And Camera Presentation

Capture is currently presented by the shell as a sheet:

- `ContentView` presents `CaptureFlowView` through `.sheet(isPresented: $navigation.isPresentingCapture)` at `snap-battle/Features/Capture/CaptureView.swift:50-59`.
- `AppNavigationModel.beginCapture()` records `destinationBeforeCapture` and opens the sheet at `snap-battle/Features/Navigation/AppNavigationModel.swift:12-15`.
- `AppNavigationModel.cancelCapture()` closes the sheet and restores the previous destination at `snap-battle/Features/Navigation/AppNavigationModel.swift:17-20`.
- `AppNavigationModel.completeCapture()` closes the sheet and selects Gallery at `snap-battle/Features/Navigation/AppNavigationModel.swift:22-25`.
- `CaptureFlowView` owns an inner `NavigationStack` at `snap-battle/Features/Capture/CaptureView.swift:157`.
- `CameraScreen` is presented as a nested sheet from `CaptureFlowView` at `snap-battle/Features/Capture/CaptureView.swift:176-181`.
- No `fullScreenCover` exists in the app code. `CameraScreen` appears immersive because `CameraPreview` uses `ignoresSafeArea()` at `snap-battle/Features/Capture/CaptureView.swift:252`.

The first implementation must keep this presentation model. Owning the bar in the shell does not require permanently incorporating the camera into a `TabView` or replacing the sheet with a new route system.

### Result Review

`PedalResultView` currently keeps preview controls in content:

- `Tocar pedal` is a content button at `snap-battle/Features/Pedal/PedalResultView.swift:37`;
- `Ver na Gallery` currently calls `onDone()` at `snap-battle/Features/Pedal/PedalResultView.swift:38`;
- result metadata animation already respects Reduce Motion at `snap-battle/Features/Pedal/PedalResultView.swift:8` and `snap-battle/Features/Pedal/PedalResultView.swift:21`.

The new bar changes result actions to:

- secondary action: `Retake`;
- primary action: `Save Pedal`;
- `Play` stays in the result content as preview, not in the bottom bar.

`Save Pedal` must follow the existing project flow after save. In the current implementation the result is displayed only after successful persistence, so `Save Pedal` maps to the existing completion path (`onComplete`, sheet dismiss, Gallery selected) and must not perform a second persistence write. If a future internal state shows a result before persistence is complete, `Save Pedal` must be disabled or loading until saving is actually available.

### Documentation Divergences

These divergences are recorded but do not block the bar:

- `specs/current/navigation-gallery-foundation.md` describes a pre-implementation context where `PedalStore` writes only `latest-pedal.json` and `latest-pedal.png`, but current `PedalStore` stores UUID-associated collection records under `pedals/` at `snap-battle/Services/Persistence/PedalStore.swift:49-125`.
- `specs/planned/gallery.md` says only the latest pedal is persisted, which is obsolete relative to current code.
- `docs/DATA_MODEL.md` describes UUID-associated collection records at `docs/DATA_MODEL.md:36-40`, but its gap list still says there is no gallery model at `docs/DATA_MODEL.md:54`.
- `docs/ROADMAP.md` mentions `generatorVersion` and original-image retention as planned direction. This bar spec does not introduce either.

### Swift And Concurrency Settings

Current build settings from `snap-battle.xcodeproj/project.pbxproj`:

- app target `snap-battle` is defined at `project.pbxproj:108-128`;
- test target `snap-battleTests` is defined at `project.pbxproj:130-145`;
- project Debug/Release `IPHONEOS_DEPLOYMENT_TARGET = 26.5` at `project.pbxproj:280` and `project.pbxproj:338`;
- app target Debug/Release `SWIFT_VERSION = 5.0` at `project.pbxproj:381` and `project.pbxproj:418`;
- test target Debug/Release `SWIFT_VERSION = 5.0` at `project.pbxproj:441` and `project.pbxproj:465`;
- app and tests set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` at `project.pbxproj:378`, `project.pbxproj:415`, `project.pbxproj:440`, and `project.pbxproj:464`;
- app Debug/Release set `SWIFT_APPROACHABLE_CONCURRENCY = YES` at `project.pbxproj:377` and `project.pbxproj:414`; tests Debug sets it at `project.pbxproj:439`;
- `SWIFT_STRICT_CONCURRENCY` is not explicitly set in the project.

This means the project uses the Xcode/toolchain 26.5 era and an iOS 26.5 deployment target, but Swift language mode is currently 5.0. Do not change build settings for this feature. Do not depend on Swift 6-only language syntax unless a separate approved change updates the project settings. This observation is not a blocker for the bottom bar.

## User Stories

- As a user on the root Gallery surface, I can see where I am and start Capture from a stable bottom control.
- As a user in the camera, I get an immersive camera UI without a persistent bar covering or duplicating camera controls.
- As a user reviewing a newly created pedal, I can preview playback in the content, retake the photo, or save/complete the pedal flow from the bar.
- As a user cancelling capture, I return to the previous real destination and the bar state matches that destination.
- As a VoiceOver user, I understand when the bottom bar changes from navigation to contextual actions.
- As a Reduce Motion user, I get the same state changes without a spatial morph.

## Functional Requirements

- Replace `MainNavigationBar` with one `ContextualBottomBar` owned by the app shell.
- Support exactly three presentation modes for the first increment:
  - `navigation`;
  - `contextual`;
  - `hidden`.
- Keep the bar instantiated once by the shell, not separately by feature screens.
- Keep two persistent visual pieces:
  - large piece;
  - small piece.
- In `navigation` mode:
  - large piece appears on the leading side;
  - large piece contains a variable list of in-scope root destinations;
  - small piece appears on the trailing side;
  - small piece contains `Capture` when capture is allowed.
- In `contextual` mode:
  - small piece appears on the leading side;
  - small piece contains the secondary action;
  - large piece appears on the trailing side;
  - large piece contains the primary action.
- In `hidden` mode:
  - the bar is visually absent;
  - controls are not hit-testable;
  - content must not be covered by an invisible bar.
- The first implementation must include:
  - current Gallery root as the initial navigation destination;
  - current Jam root placeholder as a navigable destination;
  - `Capture` action initiated by the shell;
  - camera hiding the bar;
  - result review with `Retake` as secondary action and `Save Pedal` as primary action;
  - restoration after cancel, dismiss, retake, and save/complete;
  - Reduce Motion fallback;
  - focused state/model tests and integrated transition tests for these flows.
- The first implementation must not include:
  - Jam creation, persistence, playback, collaboration, active session behavior, or final contextual Jam actions;
  - pedalboards;
  - collaborative sessions;
  - selection modes;
  - generic future action slots;
  - broad router refactors;
  - Swift language mode changes;
  - a new global design-token system beyond the local styling needed for the bar.

## Interaction States

### State Model

Use a small value-based model. Suggested shape:

```swift
enum BottomBarPresentation: Equatable {
    case navigation(NavigationBarConfiguration)
    case contextual(ContextualBarConfiguration)
    case hidden(BottomBarHiddenReason)
}
```

Suggested supporting values:

- `RootDestination`: currently the in-scope Gallery root and existing Jam root placeholder, backed by the current app destination model;
- `BottomBarAction`: stable action ID, label, system image, role, enabled/loading state, accessibility text, and shell-owned command;
- `BottomBarActionRole`: normal, cancel, destructive;
- `BottomBarHiddenReason`: camera, immersive, keyboard, unavailable.

Configurations must be data-like. Do not store arbitrary `View` values, `AnyView`, feature-owned visual styling, matched-geometry IDs, or glass IDs in feature-provided configuration.

### Derivation And Ownership

Prefer deriving the bar presentation from shell-owned state instead of introducing a generic request registry.

For the first implementation, the shell can derive the current presentation from:

- selected root destination;
- `navigation.isPresentingCapture`;
- capture flow state, such as picker, processing, save retry, result, or camera.

Do not introduce a queue of competing requests. Do not introduce a global event bus. Do not require every feature to register lifecycle tokens unless deriving from shell and route state proves insufficient.

If a view-level publication mechanism is needed later, prefer a narrow preference/modifier that publishes semantic `BottomBarPresentation` data. That is an extension point, not a first-increment requirement.

### Deterministic Priority

When more than one visible context could imply a bar presentation, resolve in this order:

1. camera or immersive hidden state;
2. active capture result, save retry, or processing state;
3. active capture picker state;
4. selected in-scope root destination navigation state;
5. fallback hidden if no in-scope root destination is available.

This priority is deterministic but intentionally small. It is scoped to the real first-increment flows.

### Navigation Mode

The navigation piece must support a variable number of destinations. The first implementation includes the current Gallery root and the existing Jam root placeholder. The mechanism must let a future spec promote Jam from placeholder to real behavior, or add another root, by changing destination configuration rather than the morph implementation.

The small piece exposes `Capture` on roots where capture is allowed. In the first increment, capture is allowed from Gallery and the Jam placeholder.

### Contextual Mode

The first increment includes these contextual states:

- capture picker/import: secondary `Cancel`, primary may remain in content for `Open Camera`/`Choose Photo` unless implementation chooses to promote one action to the bar;
- processing: hidden or disabled contextual state derived from the real processing state, with no camera action;
- save retry: secondary destructive `Discard`, primary `Try Again`;
- newly created result: secondary `Retake`, primary `Save Pedal`.

For result review:

- `Play` remains in content as preview;
- `Retake` resets or exits the current result and returns to the capture start using the existing capture presentation;
- `Save Pedal` is enabled only when the pedal can be completed/saved;
- in the current code path, where persistence already succeeded before result, `Save Pedal` uses the existing completion flow and must not write a duplicate record.

### Hidden Mode

Hidden mode applies to `CameraScreen` in the first implementation. The camera already owns a close button and shutter control at `snap-battle/Features/Capture/CaptureView.swift:258-264`, and starts/stops the camera at `snap-battle/Features/Capture/CaptureView.swift:269-270`.

Future active Jam sessions, immersive experiences, or keyboard-heavy editors must not show camera, but those flows are not part of the first increment.

## Screen And State Matrix

| Flow | Status | Bar mode | Primary action | Secondary action | Camera/Capture visible | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Gallery root | Implemented, in scope | `navigation` | Root destination selection in large piece | `Capture` in small piece | Yes | Initial navigation composition contains Gallery and the Jam placeholder. |
| Saved-pedal detail | Implemented, future extension for this bar | Not in first implementation | Undefined | Undefined | No | Existing content controls remain unchanged until a separate increment promotes detail actions into the bar. |
| Capture picker/import | Implemented as shell sheet, in scope | `contextual` or content-led capture state | Existing picker/camera choices may remain in content | `Cancel` | Capture choices inside sheet | Do not replace the current sheet mechanism. |
| Camera screen | Implemented, in scope | `hidden` | Shutter inside camera UI | Close inside camera UI | Bar hidden | Presented as nested sheet; preview ignores safe area. |
| Processing | Implemented, in scope | `hidden` or disabled `contextual` | None until state permits | Cancel only if safely wired | No | Do not expose capture. Do not imply saving before data exists. |
| Save retry | Implemented, in scope | `contextual` | `Try Again` | `Discard` | No | Mirrors current `SaveRetryView`; secondary is destructive. |
| Newly created result | Implemented, in scope | `contextual` | `Save Pedal` | `Retake` | No | `Play` remains a content preview control. |
| Jam placeholder | Implemented placeholder, in scope | `navigation` | Root destination selection in large piece | `Capture` in small piece | Yes | Root placeholder remains navigable; no Jam creation, playback, collaboration, or active session behavior is introduced. |
| Board/Pedalboard | Planned | Not in first implementation | Undefined | Undefined | No | Requires a separate Ready/In Progress spec. |
| Collaborative Jam/session | Planned | Not in first implementation | Undefined | Undefined | No | Requires a separate Ready/In Progress spec. |

## Data Model Changes

No persistent domain data changes are required.

This spec must not change:

- `PhotoPedal`;
- `PedalSequence`;
- musical generation;
- persisted note/effect/sound settings;
- `PedalStore` storage layout;
- generator versioning;
- original-image retention.

New UI/navigation state types are allowed:

- `RootDestination`;
- `BottomBarPresentation`;
- `BottomBarAction`;
- `BottomBarActionRole`;
- `BottomBarHiddenReason`.

These types must remain UI/navigation state, not persisted domain state.

## Architecture Impact

### Shell Ownership

Extract or clarify the current `ContentView` shell enough to own the new bar. The shell should own:

- selected root destination;
- capture presentation;
- Gallery model lifetime;
- App Intent routing;
- derived bottom bar presentation;
- bottom bar namespace and visual identity.

Conceptual first-increment target:

```text
AppShell / ContentView
├── Root content container
│   └── Gallery root content
├── Existing CaptureFlow sheet
│   └── Existing CameraScreen sheet
└── ContextualBottomBar
```

Do not introduce a broad router rewrite for this increment. Do not introduce a native `TabView` solely for the bar. If the implementation later adds multiple active root destinations, it may introduce one `NavigationStack` per root or an equivalent path owner at that time.

### Capture Lifecycle

The first implementation must follow the existing capture presentation:

1. On a root where capture is allowed, the shell shows `Capture` in the small piece.
2. Tapping `Capture` calls the shell-owned capture start path, equivalent to `navigation.beginCapture()`.
3. The shell presents `CaptureFlowView` with the existing `.sheet`.
4. Opening the camera uses the existing nested `.sheet` for `CameraScreen`.
5. While `CameraScreen` is active, the bar presentation is `.hidden`.
6. Returning from camera to processing/result updates the bar from shell/capture state.
7. Reaching result shows `.contextual` with `Retake` and `Save Pedal`.
8. Cancelling capture restores `destinationBeforeCapture`.
9. Retake returns to the capture start inside the existing presentation.
10. `Save Pedal` follows the current completion path; in current code this is `completeCapture()`, Gallery reload/insert, and sheet dismissal.

If the result is dismissed without `Save Pedal`, implementation must preserve current data behavior: a successfully persisted pedal remains saved, and the shell must restore an appropriate root bar state.

### App Intents

The current app has App Intents rather than URL deep links. `CreatePedalIntent` sets `.create`; `PlayLastPedalIntent` sets `.playLast` in `snap-battle/Intents/PhotoPedalIntents.swift:6-31`.

The new bar must preserve:

- `.create` enters the shell-owned capture flow;
- `.playLast` plays the latest pedal through the existing Gallery/storage playback path;
- App Intents do not directly mutate visual bar state.

## Morph And Layout Requirements

### Persistent Pieces

The two visual pieces must keep stable identities:

- `bar.primaryPiece`;
- `bar.secondaryPiece`.

Their roles change by mode:

| Mode | Large piece | Small piece |
| --- | --- | --- |
| `navigation` | Root destination collection | Capture |
| `contextual` | Primary contextual action | Secondary contextual action |
| `hidden` | Not visible | Not visible |

The implementation should animate geometry of the pieces, not recreate the entire bar.

### SwiftUI Technique

Use a stable `@Namespace` owned by the shell or persistent bar component. Use `matchedGeometryEffect` on the piece containers for the physical morph.

Liquid Glass is allowed because the deployment target is iOS 26.5, but it is not required for the first implementation. If used:

- wrap grouped glass pieces in `GlassEffectContainer`;
- apply `glassEffect(_:in:)` to piece surfaces;
- use `glassEffectID(_:in:)` for Liquid Glass morph identity;
- keep a non-glass visual fallback for accessibility, rendering, and test stability.

Do not require changing Swift language mode to implement this feature.

### Content Changes

Piece content may change with a short opacity or content transition. Icons and labels should not stretch or travel awkwardly with the piece geometry.

Avoid independent `matchedGeometryEffect` IDs on every label unless implementation proves it improves stability.

### Safe Area Strategy

Use `safeAreaInset(edge: .bottom)` for the first implementation because the current bar already uses it and it reserves space for `List` and `ScrollView` content.

Do not use a pure overlay unless implementation proves it does not cover Gallery lists, result scroll content, capture content, or keyboard content. `safeAreaBar` can be evaluated later but is not required for this increment.

### Layout Constraints

- Each interactive target must be at least 44x44 pt.
- The bar must support iPhone portrait.
- The bar must support iPad portrait and landscape, since app build settings allow iPad landscape at `project.pbxproj:363-364` and `project.pbxproj:400-401`.
- The destination list must support zero, one, or multiple future destinations without changing the piece morph mechanism.
- The bar must handle Dynamic Type through reflow, stacked icon/label layout, compact labels, or larger reserved height.
- `minimumScaleFactor` may be a last-resort protection, not the primary Dynamic Type strategy.
- Text must not overlap or disappear at accessibility text sizes.

### Reduce Motion

When `accessibilityReduceMotion` is true:

- disable spatial morph, scale, spring, and large positional animation;
- switch state with an immediate change or short opacity transition;
- preserve the same semantic actions and focus behavior.

The current app already reads `accessibilityReduceMotion` for bar press feedback at `snap-battle/Features/Capture/CaptureView.swift:79` and disables press animation at `snap-battle/Features/Capture/CaptureView.swift:137-138`.

## Accessibility

### VoiceOver Semantics

In `navigation` mode:

- root destinations expose selected state;
- `Capture` has a clear label and hint;
- the group has a useful label such as "Navegação principal";
- the implementation must remain understandable even when only one root destination is in the large piece.

In `contextual` mode:

- the secondary action is announced first if it appears visually first;
- the primary action is clearly named;
- result review exposes `Retake` and `Save Pedal`;
- labels are product actions, never implementation labels such as "large piece" or "small piece".

### Focus And Announcements

On meaningful mode changes:

- VoiceOver should receive one concise announcement, such as "Ações do pedal disponíveis";
- focus should remain stable if the focused action still exists;
- otherwise focus should move to the primary contextual action or screen title;
- returning to `navigation` should restore focus to the prior destination or action that opened the flow when practical.

### Dynamic Type, Contrast, And Color Independence

The bar must support:

- Dynamic Type through accessibility sizes;
- light mode;
- dark mode;
- Increase Contrast;
- Differentiate Without Color.

Selected, disabled, loading, and playback states must not depend only on color. Use traits, labels, symbols, shape, stroke, opacity, and text state as appropriate.

### Disabled And Loading States

Actions must use real disabled state when unavailable. Loading actions should:

- prevent repeated activation;
- show an accessible progress indicator or value;
- avoid ambiguous labels;
- keep destructive secondary actions clearly marked.

`Save Pedal` must be disabled or loading whenever the pedal cannot currently be completed/saved.

### Camera Accessibility

This feature touches camera presentation state. If implementation edits `CameraScreen`, add an explicit accessibility label/hint for the shutter button currently defined at `snap-battle/Features/Capture/CaptureView.swift:261-264`.

### Metadata Announcements

This spec must preserve `specs/current/progressive-pedal-metadata.md`: VoiceOver must announce metadata loading and completed name/description updates without relying on color alone.

## Error Handling

- If an action becomes invalid because its state disappeared, ignore it safely.
- Playback preview remains in content for the first implementation. If playback is promoted into the bar later, reuse the existing Gallery/playback error path or an equivalent accessible alert.
- Delete remains outside the first bar contract. If promoted later, it must still use confirmation and preserve failed-delete behavior.
- If save retry fails, keep the retry context active and expose the error accessibly.
- If the bar cannot resolve a valid presentation, fall back to the selected in-scope root navigation state or `.hidden` if no in-scope root is available.

## Non-Goals

- Do not implement code as part of this specification update.
- Do not implement Jam creation, persistence, playback, collaboration, active session behavior, or final contextual Jam actions.
- Do not define final Jam actions without a separate spec.
- Do not show camera in a future active Jam/session.
- Do not implement Home, Library/Pedals renaming, Profile, Board, Pedalboard, collaboration, sharing, video export, search, favorites, cloud sync, or multi-selection.
- Do not change music generation, cover generation, Foundation Models metadata boundaries, persistence layout, or audio rendering.
- Do not add `generatorVersion`.
- Do not store original images.
- Do not replace camera controls with the bottom bar.
- Do not add third-party dependencies.
- Do not change build settings or Swift language mode.
- Do not introduce a generic request queue, event bus, broad router rewrite, or global design-token system.

## Acceptance Criteria

- [ ] The app shell owns exactly one `ContextualBottomBar`.
- [ ] The bar supports `navigation`, `contextual`, and `hidden`.
- [ ] The navigation large piece accepts a variable destination collection and initially contains the in-scope Gallery root and Jam placeholder.
- [ ] The navigation small piece exposes `Capture` from Gallery and the Jam placeholder.
- [ ] Tapping `Capture` uses the existing shell-owned sheet presentation.
- [ ] `CameraScreen` shows `.hidden` and keeps its own close/shutter controls.
- [ ] Cancelling capture restores `destinationBeforeCapture` and the matching navigation bar state.
- [ ] Processing and save retry do not expose capture.
- [ ] Result review shows `Retake` as secondary and `Save Pedal` as primary.
- [ ] Result preview playback remains inside `PedalResultView` content, not in the bar.
- [ ] `Save Pedal` is disabled or loading until completion/save is available.
- [ ] In the current persisted-before-result flow, `Save Pedal` follows the existing completion path and does not duplicate persistence.
- [ ] The large and small pieces preserve stable visual identity across navigation/contextual transitions.
- [ ] The transition is not implemented as unrelated bars cross-fading.
- [ ] Reduce Motion replaces spatial morph with a simplified transition.
- [ ] App Intents for create and play latest continue to work without directly mutating visual bar state.
- [ ] Bar presentation is derived from shell/route/capture state without stale request state.
- [ ] The bar reserves safe area and does not cover scroll/list/keyboard content.
- [ ] VoiceOver exposes correct labels, hints, selected traits, and action order in both `navigation` and `contextual` modes.
- [ ] Dynamic Type at accessibility sizes does not cause overlapping or unreadable text.
- [ ] Increase Contrast and dark mode remain legible.
- [ ] Differentiate Without Color users can identify selected, disabled, loading, and playback states.
- [ ] UI tests can locate the bar and actions by stable identifiers.

## Required Tests

### Unit Or State Tests

- initial presentation is `navigation` for the in-scope Gallery root;
- Jam placeholder root presentation is `navigation`, not `hidden`;
- navigation configuration supports a variable destination collection with one destination;
- capture action transitions from root `navigation` to capture presentation state;
- camera state produces `.hidden`;
- dismissing camera restores the capture flow bar state;
- cancelling capture restores the previous root destination and navigation state;
- processing state hides the bar or produces the specified disabled contextual state without capture;
- save retry produces `Try Again` and `Discard`;
- successful result review produces `Retake` and `Save Pedal`;
- `Save Pedal` disabled/loading follows the real saved/completable state;
- `Save Pedal` completion uses existing navigation completion without duplicate persistence;
- retake returns to the capture start state;
- App Intent `.create` reaches capture without direct visual bar mutation;
- App Intent `.playLast` does not unexpectedly change bar presentation.

### UI Tests

Add stable accessibility identifiers:

- `bottomBar.root`;
- `bottomBar.mode.navigation`;
- `bottomBar.mode.contextual`;
- `bottomBar.mode.hidden`;
- `bottomBar.piece.primary`;
- `bottomBar.piece.secondary`;
- `bottomBar.destination.gallery`;
- `bottomBar.action.capture`;
- `bottomBar.action.primary`;
- `bottomBar.action.secondary`;
- `bottomBar.action.savePedal`;
- `bottomBar.action.retake`;
- `bottomBar.loading.primary`;
- `gallery.list`;
- `gallery.empty.createPedal`;
- `pedalResult.playPreview`;
- `pedalResult.savePedal`;
- `pedalResult.retake`.

UI tests should cover:

- Gallery root navigation controls;
- capture open/cancel;
- camera hidden mode;
- result `Retake` and `Save Pedal`;
- Reduce Motion launch argument or environment if available;
- large Dynamic Type launch argument if available.

### Visual And Interaction Tests

- capture screenshots in light and dark mode;
- capture screenshots with Increase Contrast;
- capture screenshots at large Dynamic Type and accessibility Dynamic Type;
- verify the bar does not cover the bottom of Gallery lists or result scroll content;
- verify the morph does not jump during capture presentation transitions.

## Device Validation

Manual validation must record pass, fail, or not run for:

- iPhone portrait Gallery navigation;
- iPad portrait and landscape Gallery navigation;
- capture open and cancel from Gallery;
- camera screen hidden mode;
- processing state;
- save retry state;
- newly created result state;
- `Retake`;
- `Save Pedal`;
- playback preview from result content;
- VoiceOver action order and announcements;
- Dynamic Type through Accessibility XXXL;
- Reduce Motion;
- Increase Contrast;
- Differentiate Without Color;
- dark mode;
- hardware keyboard Tab/Shift-Tab/Return/Space on iPad or simulator;
- App Intents through Shortcuts/Siri.

## Documentation Updates

When implementation is completed, update only documentation directly affected by the implementation:

- `docs/ARCHITECTURE.md` if an explicit app shell or derived bar state model is introduced;
- `docs/PRODUCT_SPEC.md` if result action copy or navigation copy changes;
- `docs/DEVICE_VALIDATION.md` with manual validation results;
- `docs/TESTING.md` if new UI test identifiers or launch arguments are added.

Do not update roadmap or ADRs as part of the first implementation unless a separate request authorizes it.

## Future Extensions

These are non-blocking and must not expand the first implementation:

- Promote Jam from placeholder to real destination behavior after a separate spec defines that behavior.
- Ensure any future active Jam/session never shows camera.
- Promote saved-pedal detail actions into the bar in a later increment if product wants detail to use the contextual bar.
- Add Board/Pedalboard contextual actions only after a Ready or In Progress Board spec exists.
- Add multiple root histories with one `NavigationStack` per destination if multiple active roots require independent history.
- Evaluate `safeAreaBar` after the `safeAreaInset` implementation is stable.
- Make Liquid Glass mandatory only after visual, performance, and accessibility validation justify it.

## Open Questions

No open question blocks the first implementation.
