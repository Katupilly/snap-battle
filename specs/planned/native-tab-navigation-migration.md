# Native Tab Navigation Migration

Status: Draft (retained as the decision document for the migration;
per its "Next Steps To Promote To Ready", it remains `Draft` until
the migration reaches `Done`)
Last updated: 2026-07-20

> Update 2026-07-20: the Phase 0 spike concluded with **Result A —
> Approved for production implementation**
> (`docs/audits/hybrid-tab-navigation-spike.md`). The positioning,
> padding, glass, and selection-source decisions are recorded in
> `specs/current/hybrid-tab-navigation-implementation.md`
> (promoted to `Ready`) and reflected in the "Capture Button
> Technical Proposal" and "Open Questions" sections below. File
> paths in this document were updated to the post-rename layout
> (`snap-battle/`); line numbers are approximate.

> This specification is not authorized for implementation.
> It records the divergence between the current custom bottom bar and a
> hybrid composition in which Gallery and Jam use the native `TabView`
> API and `Capture` is a narrowly scoped custom action. The current
> `ContextualBottomBar` remains the source of truth for root navigation
> and contextual actions until this spec is promoted to `Ready` or `In
> Progress` and a separate implementation spec supersedes the affected
> portions of `specs/current/contextual-bottom-bar.md`.

## Current Decision

**Proceed with native `TabView` for Gallery and Jam.**
**Keep `Capture` as a separate global action using a narrowly scoped
custom composition.**

The hybrid composition is accepted because:

- Gallery and Jam are persistent destinations and correspond correctly
  to `Tab` values.
- `Capture` is a global action and must not receive tab semantics.
- The current project baseline (iOS 26.5 / Xcode 26.5) does not offer a
  public API for a separate, non-tab, trailing action in the tab bar.
- Keeping all navigation custom only to host `Capture` blocks the
  native `TabView` benefit in the areas that already can migrate.
- The custom portion must own a narrow scope, a clear contract, and an
  explicit removal plan tied to a future toolchain upgrade.

This decision supersedes the prior recommendation in this spec
(Alternative A). Alternative A is retained in the analysis below as a
historical comparison, not as the active position.

## Target Platform

**Target platform for this migration: iPhone only.**

This specification, the technical spike it authorizes, and the
production implementation it ultimately enables are all scoped to
iPhone. iPad is explicitly out of scope. iPad-specific layout
decisions, validations, tests, screenshots, and questions are not
part of this line of work. A future specification must define iPad
navigation and `Capture` placement before the app adopts an
iPad-specific layout.

## References

- [`specs/current/contextual-bottom-bar.md`](../current/contextual-bottom-bar.md) — Ready; current root navigation, contextual actions, and bar lifecycle.
- [`specs/current/navigation-gallery-foundation.md`](../current/navigation-gallery-foundation.md) — Ready; defines Gallery and Jam as the two persistent roots and Capture as a transient action.
- [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) — app shell and dependencies.
- [`docs/DEVICE_VALIDATION.md`](../../docs/DEVICE_VALIDATION.md) — manual validation list.
- [`docs/TESTING.md`](../../docs/TESTING.md) — testing conventions.
- [`docs/AGENTS.md`](../../AGENTS.md) — sources of truth and divergence protocol.

## Goal

Authorize, in principle, a migration of root navigation from the current
custom `ContextualBottomBar` to a hybrid composition in which:

- Gallery and Jam are expressed as `Tab` values inside a native `TabView`.
- `Capture` is a separate global action rendered as a narrowly scoped
  custom view positioned alongside the native tab bar.
- Contextual workflow actions (Save Pedal, Retake, Open Camera, Cancel,
  Try Again, Discard) remain in a per-screen contextual bar with the same
  identifier contract they have today.

In `Draft` state this spec records the decision, the technical contract,
the risk surface, the migration plan, and the authorization for the
disposable technical spike that must produce the evidence the successor
specification needs. This Draft does not implement code. A separate
successor implementation specification must be `Ready` or `In Progress`
before any production change is made, and the successor specification
cannot reach `Ready` until the spike's evidence is recorded.

## Problem

The current shell renders root navigation, contextual actions, and capture
presentation from one persistent `ContextualBottomBar`
(`snap-battle/Features/Capture/CaptureView.swift:75-263`) attached with
`.safeAreaInset(edge: .bottom)` to a single `NavigationStack` rooted in
`snap-battle/Features/Capture/CaptureView.swift:13-69`. The bar is shape-correct
for the product: it differentiates persistent roots (Gallery, Jam) from a
global creation action (Capture) and from per-screen contextual actions
(Retake, Save Pedal, Try Again, Discard, Open Camera, Cancel).

The visual target captured in the Figma frame at
`figma.com/design/HBJvgh0rR2RuO2IyiJyVj/Photo-Pedal?node-id=75-140` is a
native iOS 26 tab bar with a single `TabSection` containing Gallery and Jam
plus a visually separated `Capture` action. The current custom bar is
intentionally not that visual; the gap is product cosmetic, not functional.
This spec records the gap and decides whether closing it is worth the
implementation cost in the current baseline.

The product decision is non-trivial because:

- The contextual bar carries product-critical actions (Retake, Save Pedal,
  Try Again, Discard) that are not root navigation and must remain outside
  a future `TabView` if one is adopted.
- The current shell owns exactly one source of truth for selection
  (`AppNavigationModel.selectedDestination`). Any migration must not
  introduce a second source.
- The requested visual requires a separate, modal, non-tab action that no
  currently available public API on iOS 26.5 produces natively.
- The `AGENTS.md` rules require that any production change authorized by a
  `Ready` or `In Progress` spec not silently conflict with existing
  `Ready` contracts. Today, `contextual-bottom-bar.md` is `Ready` and
  actively implemented, and `navigation-gallery-foundation.md` already
  permits `TabView` only as one acceptable option.

## Current Architecture (implementation as source of truth)

### Shell And Selection

- `snap-battle/snap_battleApp.swift:7-11` — `DapApp` opens `ContentView`.
- `snap-battle/Features/Capture/CaptureView.swift:10-69` — `ContentView` is the
  shell, despite the file path. It hosts one `NavigationStack(path:
  $navigation.path)` whose root content is selected by
  `navigation.selectedDestination`.
- `snap-battle/Features/Navigation/AppNavigationModel.swift:8-34` —
  `AppNavigationModel` is `@MainActor @Observable`. It owns
  `selectedDestination: Destination` (`.gallery` | `.jam`), `path: [AppRoute]`,
  `isPresentingCapture`, and the private
  `destinationBeforeCapture: Destination` recorded by `beginCapture()`.
  There is no second source of truth.
- `AppNavigationModel.beginCapture()` stores `destinationBeforeCapture`,
  clears `path`, and sets `isPresentingCapture = true`.
- `AppNavigationModel.cancelCapture()` clears `isPresentingCapture` and
  restores `selectedDestination` to `destinationBeforeCapture`.
- `AppNavigationModel.completeCapture()` clears `isPresentingCapture` and
  sets `selectedDestination = .gallery`. This is the only place that
  changes selection as a side effect of capture.

### Root Content

- `snap-battle/Features/Gallery/GalleryView.swift:1-91` — Gallery root; renders
  `LibraryGridView` from `snap-battle/Features/Library/LibraryGridView.swift`,
  handles deletion and playback errors, and uses
  `navigationTitle("Biblioteca")`.
- `snap-battle/Features/Pedalboard/PedalboardsView.swift:1-100` — Jam root; the
  real product screen, not the historical placeholder
  `JamPlaceholderView` from `GalleryView.swift:93-98`. It has list,
  create-board toolbar action, and `+` button to open a new board.
- `snap-battle/Features/Gallery/PedalDetailView.swift` — pushed onto `path` via
  `AppRoute.pedalDetail`. Hides the bottom bar through
  `BottomBarHiddenReason.pedalDetail` without changing
  `selectedDestination`.
- `snap-battle/Features/Pedalboard/PedalboardDetailView.swift` — pushed onto
  `path` via `AppRoute.pedalboardDetail`. Same bar-hide behavior.

### Bottom Bar

- `ContextualBottomBar` lives in
  `snap-battle/Features/Capture/CaptureView.swift:75-263`. It is instantiated
  once by the shell, not by feature views, and is attached with
  `.safeAreaInset(edge: .bottom)` to the root `NavigationStack`
  (`CaptureView.swift:26-28`).
- The bar has three modes defined in
  `snap-battle/Features/Navigation/AppNavigationModel.swift:148-219`:
  - `.navigation(NavigationBarConfiguration)` for the root Gallery and
    Jam destinations, with the `Capture` action in the small piece.
  - `.contextual(ContextualBarConfiguration)` for picker, save-retry, and
    result review inside the capture flow.
  - `.hidden(BottomBarHiddenReason)` for camera, processing, and any
    `AppRoute` that pushes a detail view.
- The bar has two physical pieces (`large-piece`, `small-piece`) with
  stable `matchedGeometryEffect` IDs in
  `CaptureView.swift:107-117` and `CaptureView.swift:175-180`. The
  contents swap while the geometry animates.

### Capture Presentation

- Capture is presented as a `.sheet(isPresented:
  $navigation.isPresentingCapture)` from the shell
  (`CaptureView.swift:50-59`).
- `CaptureFlowView` (`CaptureView.swift:148-225`) is a `NavigationStack`
  that switches between `PedalCaptureView`, `SaveRetryView`, and
  `PedalResultView` based on `CaptureViewModel` state.
- `CameraScreen` is a nested `.sheet` from `CaptureFlowView`
  (`CaptureView.swift:201-207`) with
  `CameraPreview.ignoresSafeArea()` for an immersive feel. There is no
  `fullScreenCover` anywhere in the app.
- `AppIntentRouter` (`snap-battle/Intents/PhotoPedalIntents.swift`) routes
  `.create` to `beginCapture()` and `.playLast` to
  `gallery.playLatest()` through the `onChange(of:
  AppIntentRouter.shared.request)` modifier at
  `CaptureView.swift:60-67`.

### Stable Identifiers And Tests That Depend On Them

The bar exposes stable accessibility identifiers consumed by tests and any
future UI automation:

- `bottomBar.root`, `bottomBar.mode.navigation`,
  `bottomBar.mode.contextual`, `bottomBar.mode.hidden`,
  `bottomBar.piece.primary`, `bottomBar.piece.secondary`,
  `bottomBar.destination.gallery`, `bottomBar.destination.jam`,
  `bottomBar.action.capture`, `bottomBar.action.primary`,
  `bottomBar.action.secondary`, `bottomBar.action.savePedal`,
  `bottomBar.action.retake`, `bottomBar.loading.primary`.

`snap-battleTests/NavigationGalleryTests.swift` asserts the model and the
identifier contract directly:

- `bottomBarRootIncludesGalleryAndJamDestinations` — exact destinations
  `[.gallery, .jam]` and exact identifier sequence.
- `bottomBarRootKeepsPedalboardsInNavigation` — Jam remains a navigation
  destination, not hidden.
- `pedalDetailRouteHidesBottomBarWithoutChangingSelectedRoot` — selection
  preserved across detail navigation.
- `pedalboardDetailRouteHidesBottomBarWithoutChangingSelectedRoot` — same
  for boards.
- `bottomBarCapturePhasesDeriveExpectedPresentations` — picker, processing,
  camera, save retry, result, including `savePedal.isEnabled` and
  `.isLoading`.
- `captureKeepsPrecedenceOverRootAndDetailState` — `path` is cleared on
  capture but `selectedDestination` is preserved.
- `navigationKeepsCaptureTransientAndCompletesInGallery` — Capture never
  becomes a selected destination.

### Conceptual Decomposition Today

The current bar already separates three concerns that must remain
separated by any future composition:

- Root navigation: `Gallery`, `Jam`.
- Global creation action: `Capture`.
- Contextual workflow actions: `Save Pedal`, `Retake`, `Open Camera`,
  `Cancel`, `Try Again`, `Discard`.

The bar happens to render all three through one component, but they are
logically distinct surfaces.

## Desired Architecture (invariants)

These invariants are the contract any future composition must respect. They
are derived from `contextual-bottom-bar.md`,
`navigation-gallery-foundation.md`, and the Figma frame, and are
non-negotiable regardless of which alternative is chosen.

- Gallery and Jam are the only persistent root destinations.
- Capture is a transient action, not a destination and not a tab.
- Opening Capture does not change the selected root destination. The
  selected root remains Gallery or Jam for the entire duration of the
  capture presentation.
- Cancelling Capture restores the previously selected root destination.
  Completing Capture does not break product behavior (it currently selects
  Gallery, which must be preserved unless a separate spec changes it).
- Contextual workflow actions (Retake, Save Pedal, Open Camera, Cancel,
  Try Again, Discard) are not root navigation and must not become tabs.
- Each root destination owns its own `NavigationStack` so the Gallery
  stack and the Jam stack survive independently across tab switches and
  Capture presentations.
- There is exactly one source of truth for the selected root
  destination. The implementation specification decides whether
  this source remains in `AppNavigationModel` (reinterpreted as the
  binding that backs the `TabView` selection), moves to a dedicated
  `RootNavigationSelection` value type, or is owned by the app
  shell. A second `selectedTab` stored only inside a view is
  rejected. Parallel state across two sources is rejected. Removal
  or renaming of `AppNavigationModel.Destination` and
  `selectedDestination` only happens in Increment 5 if the
  implementation evidence shows the model has become redundant.
- The migration does not change the music algorithm, the persistence
  layout, the audio engine, the camera presentation contract with
  App Intents, or the Swift language mode.

## API Analysis

### Current Baseline: Xcode 26.5 / iOS 26.5

- `TabView` with the new `Tab` value type and `TabSection` is the
  recommended way to express multiple persistent roots with the native
  Liquid Glass tab bar appearance. It supports per-tab `NavigationStack`
  through standard `NavigationStack` ownership inside the `Tab`'s
  content.
- The default `TabView` style is used. Sidebar styles and
  iPad-specific styles are not part of this migration.
- There is no public API on this baseline that places a visually
  prominent action button between or beside tabs without that action being
  a `Tab`. The requested Figma composition is not producible purely
  through public API on this baseline.
- Correction recorded after the Phase 0 spike (2026-07-20): the
  baseline **does** contain a public accessory API,
  `tabViewBottomAccessory` (iOS 26.0+, with an `isEnabled:` variant
  in iOS 26.1+). The spike prototyped it: the API renders a
  full-width accessory bar **above** the tab bar (mini-player style)
  and expands the tab bar to full width — it does not place a
  trailing action beside the capsule. The API therefore exists but
  does not produce the requested composition, and it is rejected for
  this migration. The conclusion of this section stands in practice;
  the earlier wording was factually incomplete about the API's
  existence.

### `TabRole.search`

- `TabRole.search` produces a visually distinct surface, but it carries
  the search role: the system treats it as a search surface, applies
  search-specific accessibility traits, and exposes it as a search tab
  to assistive technologies. Using it to represent Capture is
  semantically incorrect, produces misleading accessibility
  announcements, and is rejected.

### `TabRole.prominent`

- `TabRole.prominent` is part of the iOS 27 / Xcode 27 beta SDK. It
  produces a visually prominent trailing tab and is closer to the Figma
  composition than `TabRole.search`.
- It is not in the current project baseline (`IPHONEOS_DEPLOYMENT_TARGET
  = 26.5` at `snap-battle.xcodeproj/project.pbxproj`; toolchain
  is Xcode 26.5).
- It still represents a `Tab`, not a transient action. A Capture tab
  with `.prominent` would still be selectable, would still be a
  destination in the tab list, and would still compete for selection
  state with Gallery and Jam. That violates the product invariant that
  Capture is not a destination.
- Adopting it now would require changing the deployment target, the
  toolchain, and possibly the Swift language mode. The current `Ready`
  specs explicitly forbid that for the present scope.

This spec does not say "the API does not exist". It says: in the current
project baseline, the only public API that produces a visually separate
surface is `TabRole.search`, which is semantically incorrect, and the
public API that is semantically closer (`TabRole.prominent`) is not
available in the current toolchain and still does not solve the action
versus destination problem.

### Future Toolchain (Xcode 27 / iOS 27)

- `TabRole.prominent` should be re-evaluated when Xcode 27 reaches
  general availability. Even at GA it does not eliminate the action
  versus destination distinction; Capture still would need to be
  represented as a tab that re-opens the capture sheet, not as a
  destination with its own stack.
- A future hypothetical API for a center action slot in the tab bar
  would be evaluated on its own merits. No assumption is made about its
  shape, behavior, or availability.

## Visual Contract

The post-migration composition must approximate the Figma frame
(`figma.com/design/HBJvgh0rR2RuO2IyiJyVj/Photo-Pedal?node-id=75-140`)
using native `TabView` for the persistent part and a narrow custom
view for `Capture` only. The target surface is:

- A native capsule containing Gallery and Jam, with selection,
  indicator, blur, background, and transitions owned by the system.
- Liquid Glass appearance for the tab bar comes from the system. The
  implementation must not add its own blur, material, or background
  behind the tab bar.
- A `Capture` action visually separated to the trailing side of the
  same bottom region. The action uses `camera.fill` and is labeled
  "Capture" for VoiceOver regardless of whether the visible label is
  rendered.
- The `Capture` action's surface is **normal system Liquid Glass**
  (`.glassEffect(.regular.interactive(), in: .circle)`), the same
  visual family as the native tab bar — not a tinted CTA surface.
  This is the final product decision recorded after the Phase 0
  spike (see "Capture Button Technical Proposal > Visual").
- The `Capture` action is integrated visually with the tab bar region
  but is not part of the `TabView` selection model.

The implementation must not manually implement any of the following:

- selection of Gallery or Jam;
- background, blur, or material of the tab bar;
- the selected-state indicator;
- the transition between Gallery and Jam;
- the minimize or hide behavior of the tab bar;
- the safe area of the native tab bar.

The only custom composition permitted is the container and
positioning of the `Capture` action. That custom view's sole
responsibilities are: (1) calling `beginCapture()` when tapped,
(2) matching the system tab bar's visual region, and (3) being hidden
whenever the system tab bar is hidden.

The custom view's positioning is determined by the container's
layout and the public safe area. It must not measure, approximate, or
otherwise depend on a value representing the system tab bar's
internal height. The positioning follows the order of preference in
"Capture Button Technical Proposal" below.

## Technical Investigation (pre-implementation)

This subsection records the questions the implementation team must
answer before coding. They are listed here so the implementation spec
can resolve them with concrete evidence rather than assumption. Where
the answer is known from public API documentation on the current
baseline, the answer is given.

1. **How to host the `Capture` button next to the tab bar without
   covering or displacing content.** The button is a sibling of the
   `TabView`, not a child. The shell wraps the `TabView` and the
   `Capture` button in a `ZStack(alignment: .bottomTrailing)`. The
   `Capture` button is positioned using a vertical offset that
   compensates for the tab bar's intrinsic height and the bottom safe
   area. See "Capture Button Technical Proposal" below.

2. **Whether `safeAreaInset`, overlay, or another public composition
   can host the action without replacing the tab bar.** A
   `safeAreaInset(edge: .bottom)` on a tab's content would push the
   tab bar up and is rejected. An `.overlay(alignment: .bottom)` on
   the `TabView` is the public composition that does not displace
   the tab bar and does not interfere with its hit testing outside the
   button's own bounds.

3. **How the native tab bar reacts in each surface.**
   - Gallery root: tab bar visible. `Capture` overlay visible.
   - Pedal detail: tab bar hidden using `.toolbar(.hidden, for:
     .tabBar)` on the `NavigationStack` of Gallery. `Capture` overlay
     hidden in lockstep.
   - Jam root: tab bar visible. `Capture` overlay visible.
   - Pedalboard detail: tab bar hidden using the same mechanism.
     `Capture` overlay hidden in lockstep.
   - Capture presentation: the `.sheet` covers the screen. The tab bar
     is covered. The `Capture` overlay sits behind the sheet and is not
     visible.
   - Save Pedal and Retake: these are contextual actions inside the
     capture flow's per-screen contextual bar. They never coexist with
     the native tab bar.

4. **How to avoid two simultaneous bottom bars.** The contextual bar
   lives inside the capture sheet, not at the root. The `Capture`
   overlay lives at the root shell, behind the sheet. The two are
   never visible at the same time. The tab bar hides on detail screens
   in lockstep with the `Capture` overlay.

5. **How to preserve a single source of truth for the selected
   root destination.** The implementation specification decides
   where the source lives. Three options are on the table: (a) the
   source remains in `AppNavigationModel.selectedDestination`, which
   is reinterpreted as the binding that backs the `TabView`
   selection; (b) the source moves to a new `RootNavigationSelection`
   value type owned by the shell; (c) the source is owned by the
   app shell directly. The decision minimizes migration risk and
   avoids parallel state. The `beginCapture()` / `cancelCapture()` /
   `completeCapture()` methods must read and write the same source
   that the `TabView` reads and writes, regardless of which option
   is chosen. The `destinationBeforeCapture` mechanism is preserved
   by reading the current source at the moment of `beginCapture()`
   and restoring it on `cancelCapture()`. `completeCapture()` selects
   Gallery by writing the same source. The decision is not made in
   this Draft; it is made in the implementation specification after
   the technical spike provides evidence.

The minimum custom composition is the `Capture` overlay itself plus
the binding mirror that lets `AppNavigationModel` continue to drive
`beginCapture` / `cancelCapture` / `completeCapture` without owning
the selection.

## Capture Button Technical Proposal

The `Capture` action is implemented as a single SwiftUI view named
`CaptureTabAccessory` (working name) with the following contract.

**Placement.** The view is a sibling of the `TabView` inside a
container layout owned by the shell. It does not live inside any
`Tab`'s content. The container is the unit of layout for the
`TabView` and the accessory together.

**Positioning.** The accessory's position is determined by the
container's layout and the public safe area, not by a value
representing the tab bar's internal height. The implementation
follows this order of preference and tries each in this order:

1. **Shared bottom container.** The `TabView` and the accessory are
   placed in a `ZStack(alignment: .bottomTrailing)` owned by the
   shell. The `TabView` fills the container. The accessory is
   positioned by the `ZStack`'s `bottomTrailing` alignment, which
   anchors it to the container's bottom-trailing edge using the
   container's safe area. No `offset`, no `padding` meant to
   reproduce the tab bar height, no per-device constant.

2. **`safeAreaInset(edge: .bottom)` only as a fallback.** This
   technique is used only if the shared container cannot preserve
   the native tab bar's behavior (for example, if alignment pulls
   the accessory out of the tab bar's visual region in a way that
   breaks the Figma composition). The `safeAreaInset` is applied
   to the container so the system reserves the right amount of
   space. The accessory is rendered inside the inset region, not
   above it. The native tab bar remains untouched.

3. **`overlay(alignment: .bottomTrailing)`.** The last fallback.
   The `TabView` is the base; the accessory is overlaid with
   `bottomTrailing` alignment. The accessory's frame determines
   its hit area; the rest of the overlay region is non-interactive.

**Visual padding.** Only small visual paddings are allowed. These
paddings are visual breathing room from the screen edge, not
reproductions of private system dimensions. They are documented in
code with their values and validated on device before merging.
Typical values: 8 to 16 pt from the trailing edge; 0 to 8 pt above
the bottom safe area. The vertical padding must be small enough
that the accessory remains visually attached to the tab bar
region in landscape, and large enough that it does not overlap the
home indicator or sit on top of the trailing tab item.

**Chosen baseline (Phase 0 spike, iPhone 17 Pro, iOS 26.5):**

```swift
.padding(.trailing, 12)
.padding(.bottom, 4)
.offset(y: 14)
```

- 12/4 are visual paddings; `y: 14` is an optical alignment
  adjustment measured against the capsule's visual center (both
  centers coincide at 821.8 pt in the base scenario).
- No value represents a presumed tab bar height.
- Values may be refined during the real integration; any
  refinement must be global, never device-specific.

**Forbidden values.** The implementation must not:

- use any constant that represents the presumed height of the
  system tab bar;
- use a `Spacer().frame(height:)` whose height is meant to mimic
  the tab bar;
- use a per-device-class constant for vertical positioning;
- read the tab bar's frame through `GeometryReader` or any other
  measurement primitive;
- rely on a `ponytail:` constant, an internal layout estimate, or
  any value that approximates a system-private dimension.

**Safe area behavior.** The accessory follows the container's
`safeAreaInsets` changes automatically. When the system tab bar is
hidden, the accessory is hidden in lockstep (see "Hiding in lockstep
with the tab bar" below). When the device rotates, the accessory
repositions with the container. When Dynamic Type changes the
tab bar's height, the accessory follows without code change.

**Visual.** A circular button using `Image(systemName: "camera.fill")`.
The surface is **normal system Liquid Glass** — final product
decision after the Phase 0 spike:

```swift
Image(systemName: "camera.fill")
    .frame(minWidth: 56, minHeight: 56)
    .glassEffect(
        .regular.interactive(),
        in: .circle
    )
```

The normal glass integrates with the tab bar's material, adapts
naturally between light and dark mode, avoids competing with
Gallery and Jam, and keeps Capture's hierarchy as an important but
systemic action. The `camera.fill` glyph communicates the function
without a strong tint.

Tested and rejected by visual direction (not the main
implementation, and **not** an automatic fallback — it may only
return by an explicit future product decision):

```swift
.glassEffect(
    .regular.tint(.accentColor).interactive(),
    in: .circle
)
```

Rejection rationale: excessive chromatic emphasis; makes Capture
look visually separated from the tab bar; communicates more CTA
priority than desired; reduces coherence with the native
navigation material.

Also rejected by the spike's evidence: `Circle` + tint (not system
glass), `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)`
(intrinsic sizing overflows the 56×56 frame and clips at the
screen edge), `GlassEffectContainer` (identical to bare
`glassEffect` for a single element), and `tabViewBottomAccessory`
(renders a full-width bar above the tab bar; wrong composition).

The implementation does not use a third-party dependency, does not
draw a manual `Rectangle().fill(.ultraThinMaterial)`, and does not
add a custom `shadow` or `border` beyond what the system provides
for buttons in the same context. It does not use accent-color
tint, manual material, manual blur, custom shadow, artificial
border, `TabRole.search`, or `tabViewBottomAccessory` to
reproduce the trailing action.

**Hit testing.** The button's frame is a 44 by 44 minimum target. The
area outside the button's frame is not interactive: it lets taps fall
through to whatever sits below, including the `TabView`. This is the
mechanism that prevents the overlay from covering tab bar items.

**Hiding in lockstep with the tab bar.** The `CaptureTabAccessory`
reads a `TabBarVisibility` environment value (a small preference key
the implementation introduces) that is written by the navigation
stacks when they hide the tab bar. The accessory is hidden whenever
that value says the tab bar is hidden. The mechanism is symmetric and
deterministic: hiding the tab bar in code must hide the accessory;
showing the tab bar must show the accessory. There is no independent
visibility state for the accessory.

**Accessibility.** The button is a `Button` with
`accessibilityLabel("Capture")` and
`accessibilityHint("Abre a câmera para criar um pedal")`. It does not
expose itself as a tab. VoiceOver focus order puts Gallery, Jam, and
then Capture. Reduce Motion replaces any scale or spring with an
opacity change. Differentiate Without Color is respected because the
button is identified by its symbol, label, and shape, not by color
alone.

**Removal plan.** When `TabRole.prominent` or a center action API
becomes available in the project's toolchain baseline, the
`CaptureTabAccessory` is removed in a single increment. The
`TabBarVisibility` preference key and the container layout are
removed at the same time. No persistent state, identifier, or test
contract depends on the accessory after the removal.

**Stable identifiers.** The button exposes
`bottomBar.action.capture`. This identifier is the same identifier the
current contextual bar uses, so existing UI automation that targets
the capture action continues to work after the migration.

## Hybrid Composition Risks

A hybrid `TabView` plus a custom overlay introduces risks that the
implementation must actively manage. The risks are listed here so the
implementation spec can address each one explicitly.

- **Layout composition drift.** The public API does not expose an
  action slot or the tab bar's internal geometry. The accessory must
  compose with the container and the public safe area, not measure
  the tab bar. Mitigation: anchor the accessory to the container's
  bottom-trailing alignment; rely on the public safe area for the
  bottom position; validate visually by size class and orientation;
  re-validate on every iOS minor release.
- **Hit-test bleed.** If the overlay's hit area is too large, it
  intercepts taps meant for the tab bar's trailing tab (Jam). Mitigation:
  the hit area is the button's frame only. The rest of the overlay's
  region passes taps through.
- **Liquid Glass inconsistency.** A custom button background may not
  receive the same Liquid Glass treatment as the native tab bar in
  dark mode, with Increase Contrast, or in HDR. Mitigation: use a
  system component for the button surface. The first implementation
  uses a tinted `Circle` plus the system button background; if a
  `glassEffect`-based primitive is available in the baseline, the
  implementation prefers that. No custom material is used.
- **Tab bar hide synchronization.** If the tab bar is hidden by a
  navigation push but the overlay is not, the overlay floats in space.
  Mitigation: the `TabBarVisibility` preference key is the single
  switch.
- **Capture sheet and overlay.** The capture sheet covers the screen.
  The overlay is behind the sheet and is not visible. There is no
  visual conflict. Validation confirms this on iPhone.
- **VoiceOver announcement leakage.** If the overlay is exposed as a
  tab-like element to assistive technologies, VoiceOver announces a
  third tab. Mitigation: the overlay is implemented as a `Button`, not
  a `Tab`, with an explicit `accessibilityLabel` and no
  `accessibilityAddTraits(.isTab)`.
- **Reduce Motion inconsistency.** The native tab bar handles Reduce
  Motion internally. The overlay must not animate its position in a
  way that ignores Reduce Motion. Mitigation: any position or scale
  animation on the overlay reads `accessibilityReduceMotion` and
  becomes an opacity change when the user has Reduce Motion enabled.
- **Dynamic Type overflow.** The overlay's label and symbol must not
  overflow at accessibility text sizes. Mitigation: the overlay
  renders the symbol only, with the text label exposed exclusively to
  VoiceOver.
- **Stale identifier reuse.** Reusing `bottomBar.action.capture` as
  the overlay's identifier is convenient but couples two unrelated
  surfaces. The decision is acceptable as long as both surfaces are
  covered by the same contract; if the contextual bar's capture action
  is removed in the future, the identifier follows the overlay.

## Acceptance Criteria

The migration is accepted when all of the following are true:

- Gallery and Jam are inside one native `TabView` with the new `Tab`
  value type.
- The tab bar's selection, indicator, background, blur, and
  transitions come from the system. No custom equivalents are
  implemented.
- `Capture` is a `Button` rendered by a narrow custom view positioned
  alongside the native tab bar. It is not a `Tab`.
- Opening `Capture` does not change the `TabView` selection. The
  selection remains Gallery or Jam for the entire capture
  presentation.
- Cancelling `Capture` restores the previously selected tab.
- Completing `Capture` follows the existing product flow: it dismisses
  the sheet and selects Gallery, matching the current behavior.
- Each tab preserves its own `NavigationStack` across tab switches
  and across capture presentations.
- `TabRole.search` is not used for any purpose in the migrated shell.
- No new third-party dependency is introduced.
- No manual `Rectangle`, `.background(.ultraThinMaterial)`,
  `.shadow`, or other visual primitive is used to imitate Liquid Glass
  in the tab bar.
- The contextual bar continues to expose Save Pedal, Retake, Open
  Camera, Cancel, Try Again, and Discard with the same accessibility
  identifiers and the same behavior.
- The contextual bar is hidden in lockstep with the native tab bar on
  detail screens. There is no screen in the app where two bottom bars
  are visible at the same time.
- VoiceOver announces Gallery and Jam as the tabs. `Capture` is
  announced as a button, not a tab. `Capture` is never announced as
  selected.
- `IPHONEOS_DEPLOYMENT_TARGET`, `SWIFT_VERSION`, and the toolchain
  are unchanged.
- `xcodebuild build -configuration Debug` and `-configuration Release`
  succeed.
- The full test suite passes.
- Manual validation on simulator and on a physical device covers:
  Gallery as initial tab, Gallery-Jam switch, Capture from Gallery,
  cancel from Gallery, Capture from Jam, cancel from Jam, photo
  capture flow, Gallery detail, Jam detail, Restore selection, no
  layout jumps, no bar covers controls, light and dark mode, VoiceOver,
  Reduce Motion, Increase Contrast, Differentiate Without Color,
  Dynamic Type through accessibility XXXL.
- New tests cover the hybrid composition's invariant: the `TabView`
  selection is Gallery or Jam; `Capture` is not in the selection set;
  opening and closing `Capture` does not change the selection.
- The `CaptureTabAccessory` follows safe area changes automatically
  in response to rotation, Dynamic Type, and tab bar height changes.
- The `CaptureTabAccessory` does not depend on a value that
  represents the presumed height of the system tab bar. The
  implementation must not contain a `ponytail:` constant, a per-
  device-class constant, a `Spacer().frame(height:)` mimicking the
  tab bar, or a `GeometryReader` measuring the tab bar.
- The `CaptureTabAccessory` does not break in landscape on iPhone.
- The `CaptureTabAccessory` does not break when Dynamic Type is
  changed at runtime, including at accessibility sizes.
- The `CaptureTabAccessory` does not remain floating in space when
  the tab bar is hidden. The `TabBarVisibility` preference key is
  the only switch.
- Manual validation is performed on at least one iPhone with
  Dynamic Island and one iPhone without Dynamic Island, if
  fixtures or devices are available.

## Alternatives

### Alternative A — Keep The Current Custom Composition

Keep `ContextualBottomBar` as the only root and contextual navigation
component. No new API is introduced. `AppNavigationModel` remains the
single source of truth for selection.

Pros:

- Preserves the current contract end to end, including all stable
  identifiers, all existing tests, and the contextual bar state machine.
- Capture remains semantically correct as an action, not a destination.
- Contextual actions (Retake, Save Pedal) remain in the right place and
  are not lost.
- Zero risk to capture, save, and detail flows that are already
  validated.
- No toolchain or deployment target change.

Cons:

- The visual target of the Figma frame is not reached. The bottom of the
  screen does not use the native Liquid Glass tab bar.
- The custom composition must be maintained indefinitely.
- The shell continues to be implemented in
  `snap-battle/Features/Capture/CaptureView.swift`, which is a non-obvious home
  for a root navigation component.

### Alternative B — `TabView` For Gallery And Jam; Capture As Delimited Custom Composition

Introduce a `TabView` with two `Tab`s (Gallery, Jam) that each own a
`NavigationStack`. Move `Capture` out of any `Tab` and render it as a
single, delimited custom action attached to the `TabView` root (for
example, an overlay anchored to the bar's safe area, or a separate
control outside the tab list). Keep all contextual workflow actions in
the existing `ContextualBottomBar` attached per-screen.

Pros:

- Root navigation uses the native tab bar API and inherits the native
  Liquid Glass appearance.
- Each root owns its own `NavigationStack`, which matches the existing
  per-root stack model and removes the `path.removeAll()` workaround in
  `beginCapture()`.
- The contextual bar can keep its three-mode lifecycle because its
  scope is now the capture flow plus detail views, not the root
  navigation.

Cons:

- The composition becomes hybrid: a native `TabView` plus a custom
  Capture action. The custom Capture action must be carefully
  positioned, sized, and made accessible without colliding with the
  system bar's safe area, hit testing, or focus order.
- The exact Figma frame requires either an undocumented public API or
  a custom composition. Any custom composition is a deliberate
  approximation and must be documented as such with a clear ceiling and
  an upgrade path.
- The contextual bar's "navigation" mode is split off and replaced by
  the `TabView`. The bar's API surface shrinks, but its public types
  (`BottomBarPresentation`, `RootDestination`,
  `NavigationBarConfiguration`) must be retired or repurposed. This is
  a structural change that affects tests, identifiers, and any UI
  automation.
- The hybrid form increases the risk of safe area conflicts between the
  native tab bar, the contextual bar, the capture sheet, and the home
  indicator on devices without a home button.
- It does not, by itself, reach the Figma frame. The action button is
  still approximated.

### Alternative C — Defer Migration To A Future Toolchain

Keep the current composition. Track `TabRole.prominent` and any future
tab-bar API that targets an action slot rather than a destination. Reopen
this spec when Xcode 27 reaches general availability in the project's
toolchain.

Pros:

- No transit code. No partial state. No temporary visual.
- Lets the project”).spec wait for an API that may actually solve the
  action-versus-destination distinction.

Cons:

- The migration is delayed. The Figma frame remains unmet.
- There is no guarantee that the future API solves the Capture-is-not-a-
  destination requirement. Adopting a future `TabRole.prominent` still
  treats Capture as a tab.
- The product visual target remains a custom composition for an
  indefinite period.

### Alternative D — Use `TabRole.search` As Capture

Reject. Rejected for all the reasons in the API analysis:

- Semantically incorrect. `TabRole.search` carries the search role and
  exposes search-specific accessibility traits and system behaviors.
- Misleading accessibility: VoiceOver announces a search tab, not a
  capture action.
- Behaviorally wrong: tapping it does not just open a modal; the
  system may try to convert the tab into a search field.
- The visual is a byproduct of the role, not a designed effect.

This alternative is recorded for the record. It is not under
consideration.

## Recommendation

Recommendation: **Alternative B (native `TabView` for Gallery and Jam;
narrowly scoped custom composition for `Capture`).**

The earlier recommendation (Alternative A) is reversed by the
`Current Decision` block at the top of this spec. Alternative A is kept
in the analysis as a historical comparison.

Rationale for the new recommendation, in priority order:

1. **Native behavior where it is available.** Gallery and Jam are
   persistent destinations. `TabView` and `Tab` are the system-provided
   way to express persistent destinations, including the per-tab
   `NavigationStack` ownership that this product already needs and that
   the current shell approximates with `path.removeAll()` on
   `beginCapture()` (`AppNavigationModel.swift:14`).
2. **Custom only where the SDK does not help.** The current baseline
   does not expose a public API for a visually separate, non-tab action
   in the tab bar. A custom composition for `Capture` is therefore
   unavoidable if the Figma composition is the target. Limiting the
   custom code to the smallest possible surface keeps the rest of the
   shell native.
3. **Capture is an action, not a destination.** `Capture` must not be a
   `Tab`. The hybrid composition preserves this by placing `Capture`
   outside the `TabView` selection model. The selection state in
   `TabView` is `Gallery | Jam` only.
4. **Single source of truth for selection.** The implementation
   preserves a single source of truth for the selected root
   destination. The implementation specification decides whether
   this source remains in `AppNavigationModel` (reinterpreted as the
   binding that backs the `TabView` selection), moves to a dedicated
   `RootNavigationSelection` value type, or is owned by the app
   shell. The decision minimizes migration risk and avoids parallel
   state. The use of `TabView(selection:)` does not necessarily
   require deleting the current model; the safer path is to adapt
   `selectedDestination` to act as the binding during the early
   increments. Removal or renaming of `AppNavigationModel.Destination`
   and `selectedDestination` only happens in Increment 5 if the
   implementation evidence shows the model has become redundant.
5. **Contextual actions survive.** Save Pedal, Retake, Open Camera,
   Cancel, Try Again, Discard remain in the existing contextual bar,
   which is reduced to its per-screen scope. The contextual bar
   continues to be owned by the app shell, not by feature views.
6. **Reversibility.** The five-increment plan below is structured so
   that any increment can be reverted without invalidating the rest.
   Increment 1 is a pure refactor. Increment 5 removes obsolete code
   only after the new shell is in production.
7. **Toolchain stability.** The migration does not require
   `IPHONEOS_DEPLOYMENT_TARGET` above 26.5, does not require Xcode 27
   beta, does not require `TabRole.prominent`, and does not change the
   Swift language mode. It works on the project's current baseline.

## Impact On Existing Specs

This Draft does not change the status of any existing spec. It records
the divergence and proposes how a successor implementation spec will
partially supersede `specs/current/contextual-bottom-bar.md`. The
contextual portions of that spec survive the migration. The
root-navigation portions become superseded.

### `specs/current/contextual-bottom-bar.md` (Ready)

**Survives unchanged:**

- The state model `BottomBarPresentation` for the `.contextual` and
  `.hidden` cases. These cases are used inside the capture flow's
  per-screen contextual bar and continue to operate as today.
- The contextual action vocabulary: `Save Pedal`, `Retake`, `Open
  Camera`, `Cancel`, `Try Again`, `Discard`. The action types
  (`BottomBarAction`, `BottomBarActionRole`) and the
  `CaptureFlowPhase` enum are preserved.
- The accessibility identifiers for contextual actions
  (`bottomBar.action.savePedal`, `bottomBar.action.retake`,
  `bottomBar.action.primary`, `bottomBar.action.secondary`,
  `bottomBar.loading.primary`).
- The Reduce Motion behavior for contextual press feedback
  (`PressFeedbackButtonStyle` in `CaptureView.swift:265-272`).
- The `matchedGeometryEffect` IDs `large-piece` and `small-piece` for
  the contextual bar (used only inside the capture flow after the
  migration).

**Partially superseded:**

- The `.navigation(NavigationBarConfiguration)` case of
  `BottomBarPresentation` and the supporting `RootDestination` and
  `NavigationBarConfiguration` types
  (`AppNavigationModel.swift:148-219` and
  `AppNavigationModel.swift:96-105`).
- The `RootDestination.gallery` and `RootDestination.jam` accessibility
  identifiers when they are owned by the contextual bar. After the
  migration, the tabs expose the same logical labels through the
  `TabView`'s own accessibility surface. The new tab identifiers are
  `tab.gallery` and `tab.jam`. The `bottomBar.destination.*`
  identifiers are removed when the bar stops carrying them.
- The bar's `bottomBar.root`, `bottomBar.mode.navigation`,
  `bottomBar.piece.primary`, and `bottomBar.piece.secondary`
  identifiers when they reference the root navigation portion of the
  bar. These become obsolete when the bar no longer renders
  navigation.
- The bar's `bottomBar.action.capture` identifier. After the
  migration, this identifier is owned by the `CaptureTabAccessory`
  view. The contract is the same: the capture action exposes this
  identifier wherever it is rendered.

**Documentation drift to track:**

- `contextual-bottom-bar.md:29` says "There is no native `TabView`".
  After the migration this is false. The successor implementation
  spec updates this line as part of its documentation pass.
- `contextual-bottom-bar.md:54` and `:289` forbid introducing a
  `TabView`. After the migration these are no longer accurate for
  the affected portions. The successor spec rewords or marks them as
  superseded.
- `contextual-bottom-bar.md` still refers to the Jam root as a
  placeholder. The real Jam root is `PedalboardsView`. The successor
  spec records this as a long-standing documentation drift and
  resolves it.

**How the partial supersession is recorded:**

- The successor implementation spec adds a "Superseded by" header at
  the top of `contextual-bottom-bar.md` only for the affected
  sections, following the template in
  `specs/planned/gallery.md`. The body of the spec is not rewritten.
  The contextual sections remain authoritative for the contextual bar.

### `specs/current/navigation-gallery-foundation.md` (Ready)

- No paragraph is changed by the present Draft. The migration
  satisfies the navigation requirements of this spec verbatim:
  Gallery and Jam remain the only persistent destinations; Capture
  remains a transient action; the previously selected destination is
  restored on cancel; successful capture selects Gallery.
- The successor implementation spec re-asserts the navigation
  requirements in its Acceptance Criteria so reviewers can confirm
  the migration preserves them.

### ADRs

- `docs/decisions/0001-deterministic-local-music-generation.md`,
  `0002-persist-generated-musical-results.md`,
  `0003-foundation-models-for-semantic-metadata.md`, and
  `0005-image-processing-concurrency-boundary.md` are not affected.
- `docs/decisions/0004-board-uses-a-shared-global-clock.md` is
  `Proposed` and is not affected.
- No new ADR is created by this Draft. If a future toolchain
  upgrade makes `TabRole.prominent` available, an ADR may be
  proposed at that time to record the choice between
  `TabRole.prominent` and continued use of the custom accessory.
  That ADR is not part of this migration.

## Incremental Plan

This is the active plan. Each increment is small, reversible, and
tested in isolation. The plan is not authorization. The plan becomes
authorization only after this spec is promoted to `Ready` and a
successor implementation spec is `Ready` or `In Progress`.

### Increment 1 — Separate Root Navigation From Contextual Actions

**Goal:** split the `ContextualBottomBar`'s responsibilities so that
the root-navigation portion can be replaced in Increment 2 without
touching the contextual portion. This is a refactor with no visual
change.

- Remove `Gallery` and `Jam` from the contextual bar's contract. The
  bar stops being responsible for switching between them.
- Keep `Capture`, `Save Pedal`, `Retake`, `Open Camera`, `Cancel`,
  `Try Again`, and `Discard` in the bar. The contextual vocabulary
  is unchanged.
- The implementation must preserve a single source of truth for the
  selected root destination. The implementation specification
  decides whether this source remains in `AppNavigationModel`
  (reinterpreted as the binding that backs the `TabView` selection),
  moves to a dedicated `RootNavigationSelection` value type, or is
  owned by the app shell. The decision minimizes migration risk and
  avoids parallel state. The decision is not made in this Draft.
- The safer path is to adapt `AppNavigationModel.selectedDestination`
  to act as the binding that backs the `TabView` selection during
  the early increments, leaving the model in place until the
  implementation evidence shows the property is truly redundant.
  Removal or renaming of `AppNavigationModel.Destination` and
  `selectedDestination` only happens in Increment 5 if the
  implementation evidence shows the model has become redundant.
- Update `NavigationGalleryTests.swift`:
  - `bottomBarRootIncludesGalleryAndJamDestinations` is rewritten to
    test the new source of truth, whatever the implementation
    specification chose.
  - `bottomBarRootKeepsPedalboardsInNavigation` is rewritten to test
    the new model.
  - The contextual tests
    (`bottomBarCapturePhasesDeriveExpectedPresentations`,
    `captureKeepsPrecedenceOverRootAndDetailState`, and the others
    listed in the Test Matrix) are preserved verbatim.

**Reversibility:** the refactor is reversible by restoring the
contextual bar's responsibility for the root-navigation portion.
The model may continue to back the `TabView` selection with no
user-visible behavior change.

### Increment 2 — Introduce `TabView` For Gallery And Jam

**Goal:** replace the root-navigation portion of the custom bar with
a native `TabView` while preserving all contextual behavior. `Capture`
is not yet rendered; the contextual bar still owns it.

- Wrap the existing Gallery and Jam content in a `TabView` with one
  `TabSection` containing two `Tab`s. Each `Tab` owns its own
  `NavigationStack`.
- Bind the `TabView` selection to a `@State` value owned by the
  shell. The shell is the single source of truth.
- The contextual bar's `.navigation` case is removed. The contextual
  bar keeps `.contextual` and `.hidden`.
- Hide the native tab bar on detail screens using
  `.toolbar(.hidden, for: .tabBar)` at the `NavigationStack` boundary
  of Gallery and of Jam. Hide it inside the capture sheet using the
  same modifier.
- The contextual bar's existing
  `bottomBar.action.capture` is rendered inside the contextual bar
  during the capture flow as today. The new `TabView` does not yet
  show a `Capture` action.
- New tests:
  - Gallery is the initial tab.
  - Gallery-Jam switch preserves each tab's `NavigationStack`.
  - Detail navigation hides the tab bar without changing the
    selected tab.
  - `Capture` is not present in the `TabView` selection set.

**Reversibility:** revert by restoring the contextual bar's
`.navigation` case and removing the `TabView`. The
`RootNavigationSelection` from Increment 1 remains.

### Increment 3 — Integrate The `Capture` Action

**Goal:** add the `CaptureTabAccessory` view described in "Capture
Button Technical Proposal" above. Render it alongside the `TabView`
as a sibling inside a `ZStack(alignment: .bottomTrailing)`. Wire it to
`beginCapture()`.

- Implement `CaptureTabAccessory` per the technical proposal.
- Add the `TabBarVisibility` preference key and wire it to the
  navigation stacks in Gallery and Jam. The accessory reads it and
  hides itself in lockstep with the tab bar.
- Remove the `Capture` action from the contextual bar's root
  navigation (it was already removed in Increment 1; this increment
  ensures it is no longer rendered at the root).
- Wire `beginCapture` / `cancelCapture` / `completeCapture` to the
  new selection model:
  - `beginCapture` records the current `TabView` selection as
    `destinationBeforeCapture` and opens the sheet.
  - `cancelCapture` closes the sheet and restores the recorded
    selection.
  - `completeCapture` closes the sheet and writes Gallery into the
    selection binding.
- Tests:
  - `Capture` is not a `Tab` value. The selection set is
    `{Gallery, Jam}`.
  - Opening `Capture` from Gallery leaves the selection at Gallery.
  - Opening `Capture` from Jam leaves the selection at Jam.
  - Cancelling `Capture` restores the previously selected tab.
  - Completing `Capture` selects Gallery.
  - `Capture` is exposed as a `Button` with the identifier
    `bottomBar.action.capture`.

**Reversibility:** the accessory is removed and `beginCapture` /
`cancelCapture` / `completeCapture` are re-pointed at the contextual
bar. The `TabView` from Increment 2 remains.

### Increment 4 — Visibility And Contextual Bar Coordination

**Goal:** ensure the native tab bar, the `Capture` accessory, and the
contextual bar never coexist visually in any screen.

- Verify `.toolbar(.hidden, for: .tabBar)` is applied at the right
  `NavigationStack` boundary for each detail screen and for the
  capture sheet. Document the boundaries in code comments.
- Verify the contextual bar is hidden whenever the capture sheet
  closes (the current code already handles this through
  `BottomBarHiddenReason`).
- Verify there is no screen in the app where two bottom surfaces are
  visible simultaneously. Add an integration test that walks the
  state machine and asserts on the visible bar surfaces per state.
- Add UI tests for the new `tab.gallery` and `tab.jam` identifiers
  on the `TabView`.
- Manual validation on iPhone, portrait and landscape, light and
  dark mode, accessibility text sizes, Reduce Motion.

**Reversibility:** the visibility coordination is local to the
`TabBarVisibility` preference key and the `.toolbar` modifiers.
Reverting Increment 4 leaves Increments 1 to 3 functional.

### Increment 5 — Remove Obsolete Infrastructure

**Goal:** delete the code and identifiers that no longer
participate in the new architecture, but only if the implementation
evidence shows they are truly redundant.

- If the implementation chose to keep `AppNavigationModel.Destination`
  and `selectedDestination` as the binding that backs the `TabView`
  selection, those types are removed only if the implementation
  evidence shows they have become redundant. The criterion is "is
  the type still read by any code outside the `TabView` selection
  binding?" If the answer is no, the type is removed. If the answer
  is yes, the type is kept.
- Remove `RootDestination` and `NavigationBarConfiguration` if they
  were introduced in Increment 1 and have no remaining reader.
- Remove the `.navigation` case of `BottomBarPresentation` and the
  related presentation helpers
  (`BottomBarPresentation.root(selected:)`,
  `BottomBarPresentation.forNavigation(_:)`).
- Remove the contextual bar's `large-piece` and `small-piece`
  `matchedGeometryEffect` geometry if no longer used in any mode.
  The contextual bar may keep a simpler layout for its `.contextual`
  and `.hidden` modes.
- Remove the `bottomBar.destination.*` identifiers and any other
  identifiers that the contextual bar no longer exposes.
- Update tests:
  - Remove tests that asserted the deleted `RootDestination` and
    `NavigationBarConfiguration` contracts.
  - Add tests that assert the new `tab.gallery` and `tab.jam`
    identifiers on the `TabView`.
  - Add tests that assert `Capture` is not a `Tab` value.
- Update `docs/ARCHITECTURE.md` and `docs/TESTING.md` to reflect the
  new shell.
- Update `contextual-bottom-bar.md` to mark the root-navigation
  sections as superseded, following the `Superseded by` template in
  `specs/planned/gallery.md`. The body of the spec is not rewritten.
  The contextual sections remain authoritative.

**Reversibility:** at this point the migration is final. Reverting
Increment 5 is not part of the migration; if the team needs to
revert the whole change, the migration is rolled back by reverting
Increments 5, 4, 3, 2, 1 in order on a separate branch.

## Test Matrix

### Tests Preserved Without Rewrite

These assertions remain valid regardless of the chosen alternative:

- Capture lifecycle: `navigationKeepsCaptureTransientAndCompletesInGallery`
  and `captureKeepsPrecedenceOverRootAndDetailState` test the
  `AppNavigationModel` state machine. They are independent of the bar
  implementation.
- Pedal detail preserves selection:
  `pedalDetailRouteHidesBottomBarWithoutChangingSelectedRoot` and
  `pedalboardDetailRouteHidesBottomBarWithoutChangingSelectedRoot`
  assert the model contract, not the visual.
- `detailRouteUsesOnlyPersistentID` is pure data.
- `AppRoute` equality is pure data.
- `navigationOpensPedalboardDetailByPersistentID` is pure data.
- `bottomBarCapturePhasesDeriveExpectedPresentations` is split
  conceptually. The contextual cases (picker, save retry, result)
  survive any migration. The hidden cases (camera, processing) survive
  any migration.

### Tests That Must Be Rewritten Or Replaced

- `bottomBarRootIncludesGalleryAndJamDestinations` and
  `bottomBarRootKeepsPedalboardsInNavigation` assert the
  `BottomBarPresentation.navigation` configuration. Under the
  active decision (Alternative B) they are rewritten to assert the
  new `RootNavigationSelection` and the `TabView`'s selection.
  They are rewritten in Increment 1, before the `TabView` is
  introduced.
- Any UI test that locates the root navigation by accessibility
  identifier on the custom bar is rewritten to locate the `TabView`'s
  tabs by their new `tab.gallery` and `tab.jam` identifiers. This
  is part of Increment 2.

### New Tests Required

- Gallery is the initial tab on launch.
- Switching between Gallery and Jam preserves each tab's `NavigationStack`.
- Opening Capture from Gallery keeps Gallery selected throughout the
  capture presentation.
- Opening Capture from Jam keeps Jam selected throughout the capture
  presentation.
- Cancelling Capture restores the previously selected tab.
- Completing Capture selects Gallery and reveals the new pedal.
- Capture is never announced as a selected tab.
- Tab bar is hidden in `PedalDetailView` and `PedalboardDetailView`.
- Tab bar is hidden during capture.
- Tab bar is hidden during `CameraScreen`.
- Tab bar is hidden during processing.
- `Save Pedal` follows the existing completion path and does not
  duplicate persistence.
- `Retake` returns to the capture start.
- VoiceOver announces the contextual actions in visual order.
- VoiceOver does not announce Capture as a tab.
- Reduce Motion replaces any spatial morph with an opacity change.
- Dark mode and light mode are both visually correct.
- Dynamic Type through accessibility XXXL does not break the bar.
- Increase Contrast remains legible.
- Differentiate Without Color users can identify selected, disabled,
  and loading states.

### Hybrid Composition Tests

- The `TabView` selection set is exactly `{Gallery, Jam}`. `Capture`
  is not a `Tab` value.
- The `CaptureTabAccessory` exposes the identifier
  `bottomBar.action.capture`.
- The `CaptureTabAccessory` is visible whenever the system tab bar
  is visible at the root of Gallery or Jam.
- The `CaptureTabAccessory` is hidden whenever the system tab bar is
  hidden on detail screens and during capture.
- The `CaptureTabAccessory`'s hit area is a 44 by 44 minimum target
  and does not cover the trailing tab of the `TabView` (Jam).
- The contextual bar and the `CaptureTabAccessory` are never visible
  at the same time.
- The `TabBarVisibility` preference key is the only switch that hides
  the `CaptureTabAccessory`. There is no independent visibility state.

### Risks Of Tests Based On Internal SwiftUI Hierarchy

The existing tests assert on the `BottomBarPresentation` model, which
is the right level. They do not assert on the SwiftUI view tree. New
tests for the hybrid composition assert on the model and on the
accessibility identifiers, not on the SwiftUI hierarchy. Tests that
walk the SwiftUI view tree, inspect the `TabView`'s internal
`Tab` values, or look up `matchedGeometryEffect` IDs break across
SwiftUI minor versions and are rejected. The model and the
accessibility identifiers are the stable surface.

## Out Of Scope

The following are explicitly not part of this migration and must not be
touched by any future implementation spec derived from this Draft:

- Changing the Gallery icon.
- Changing the Jam icon.
- Implementing the Vibe product surface.
- Redesigning `PedalboardsView` or `PedalboardDetailView`.
- Changing the Capture presentation from `.sheet` to `.fullScreenCover`.
- Changing the Swift language mode.
- Changing the deployment target or toolchain.
- Adopting Xcode 27 beta APIs.
- Changing the music generation algorithm, the cover generation, or the
  audio engine.
- Changing the persistence layout.
- Changing the App Intents contract.

## Open Questions

The architectural direction is decided. The open questions that
remain are product, naming, and three concrete implementation
decisions listed below. They are answered by the technical spike
described in the next section, not by this Draft. iPad-specific
questions are not part of this line of work.

- The Figma frame's copy: `Biblioteca` (used today) versus `Gallery`
  (used in the Figma). Any decision here blocks the icon and label
  work that is currently listed in `Out Of Scope`.
- ~~The specific small visual paddings the accessory uses.~~
  **Resolved by the Phase 0 spike** (2026-07-20): trailing 12 pt,
  bottom 4 pt, optical `offset(y: 14)`; baseline values, globally
  refinable during integration, none representing a presumed tab
  bar height. Evidence: `docs/audits/hybrid-tab-navigation-spike.md`.
- ~~Which of the three positioning techniques in the order of
  preference is actually used.~~ **Resolved by the Phase 0 spike:**
  shared container (`ZStack(alignment: .bottomTrailing)`), first in
  the order of preference; `tabViewBottomAccessory` was also
  evaluated and rejected. Evidence:
  `docs/audits/hybrid-tab-navigation-spike.md`.
- ~~The single-source-of-truth strategy for the selected root
  destination.~~ **Resolved:** `TabView(selection:)` binds to the
  existing selection source; the implementation adapts
  `AppNavigationModel.selectedDestination` during the early
  increments with no parallel state; a dedicated
  `RootNavigationSelection` is extracted only if the
  implementation demonstrates a concrete need.
- Whether `TabRole.prominent` (when it reaches the project's
  toolchain) replaces the `CaptureTabAccessory` entirely or only on
  selected device classes. This Draft does not decide. A future ADR
  may propose a choice when the API is available.

## Authorized Technical Spike

A disposable technical spike is authorized while this specification
remains `Draft`. Its only purpose is to resolve the layout, padding,
and single-source-of-truth strategy questions that block the
successor implementation spec from being promoted to `Ready`. The
spike is **not** production implementation and is **not** merged.

The spike:

- is not production implementation;
- does not replace the current `ContextualBottomBar` shell;
- does not modify any `Ready` or `In Progress` specification;
- does not branch from `main` in a way that the team is expected to
  merge;
- lives on a separate, short-lived branch;
- may contain throwaway code, instrumented views, and provisional
  identifiers;
- is discarded or reset after the evidence is collected and recorded
  in `docs/audits/hybrid-tab-navigation-spike.md`;
- does not need to preserve complete compatibility with the existing
  test suite;
- does not need to update the existing test suite beyond the spike's
  own instrumentation;
- does not remove or rename the current `ContextualBottomBar`,
  `AppNavigationModel`, `RootDestination`, or any other currently
  live code;
- does not modify `PedalStore`, the audio engine, the music
  generation algorithm, the Foundation Models metadata flow, the
  camera presentation, or the App Intents contract.

The spike's required behavior, scope, and evidence format are
defined in the successor implementation specification
`specs/current/hybrid-tab-navigation-implementation.md`, Phase 0.
That specification is the only authority for what the spike does.

The successor implementation specification is promoted to `Ready` (or
`In Progress`) only after the spike's evidence is recorded and the
spike's answers are incorporated into the successor specification.
The successor specification cannot reach `Ready` on the basis of
this Draft alone.

## Next Steps To Promote To Ready

1. The successor implementation specification
   `specs/current/hybrid-tab-navigation-implementation.md` is written
   in `Draft` state. It references this specification, the captured
   `Current Decision`, the `Visual Contract`, the `Technical
   Investigation` answers, the `CaptureTabAccessory` proposal, the
   `Hybrid Composition Risks`, the `Incremental Plan`, and the
   `Authorized Technical Spike` section above.
2. The successor specification authorizes the spike (Phase 0) only.
   Production implementation is not authorized by either the
   successor specification in `Draft` state or by this Draft.
3. The spike is executed on a short-lived branch. The spike's
   evidence is recorded in `docs/audits/hybrid-tab-navigation-spike.md`
   using the `Observed` / `Inferred` / `Not validated` format the
   successor specification requires.
4. The successor specification incorporates the spike's answers into
   its `Acceptance Criteria`, its selection of the positioning
   technique, its visual padding values, and its
   single-source-of-truth strategy.
5. The successor specification's `Acceptance Criteria` are checked
   against the ones in this specification. The successor
   specification's set must be a superset, not a subset, of this
   specification's set.
6. The successor specification lists the manual validation items for
   iPhone that the device-validation section of this specification
   requires. Items it cannot run are reported as `not run`.
7. The successor specification is reviewed. Reviewers confirm:
   - the spike's evidence is recorded and cited in the successor
     specification;
   - the `TabView` selection is the single source of truth
     (whichever of the three options was chosen);
   - the `CaptureTabAccessory` is the only custom composition;
   - the contextual bar's identifiers are preserved;
   - the `matchedGeometryEffect` IDs are removed if unused;
   - `docs/ARCHITECTURE.md` and `docs/TESTING.md` updates are scoped
     to the migration.
8. The successor specification is promoted to `Ready` (or `In
   Progress`). At that point the migration can begin, starting at
   Increment 1 of the Incremental Plan.
9. This Draft remains `Draft` until the migration reaches `Done` (or
   is abandoned). It is then archived alongside the successor
   specification.
