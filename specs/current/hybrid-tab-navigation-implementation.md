# Hybrid Tab Navigation — Implementation Spec

Status: Ready
Last updated: 2026-07-20

> Promoted from `Draft` to `Ready` on 2026-07-20 after the Phase 0
> spike concluded with **Result A — Approved for production
> implementation** (`docs/audits/hybrid-tab-navigation-spike.md`).
> All promotion criteria in "Acceptance Criteria for Promoting This
> Spec to Ready" are satisfied; the required sections
> ("Selected Implementation Decisions", "Visual Differences vs.
> Figma", "Manual Validation Items", "Preference Key Contract",
> "Documentation Updates") are present below. The Round 2 reduced
> test matrix (base scenario + Jam + dark only) and the deferred
> production validation matrix were explicitly approved by the
> product owner.
>
> **This specification authorizes production implementation** of the
> migration described in
> `specs/planned/native-tab-navigation-migration.md`, increment by
> increment, each on its own branch. The migration spec remains
> `Draft` as the decision document until the migration reaches
> `Done`. The approved Increment 3 visual uses a **capsule Capture
> accessory** with a blue luminous gradient under interactive
> regular Liquid Glass.
>
> File paths in this document were updated to the post-rename
> layout (`Dap/`).

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

- [`specs/planned/native-tab-navigation-migration.md`](../planned/native-tab-navigation-migration.md) — direction, technical contract, risk surface, incremental plan, decision document (remains `Draft` until the migration reaches `Done`).
- [`docs/audits/hybrid-tab-navigation-spike.md`](../../docs/audits/hybrid-tab-navigation-spike.md) — Phase 0 spike report, two rounds; approved-visual evidence (normal glass) at `docs/audits/assets/hybrid-tab-spike/34-final-gallery-light(-annotated).png`, `35-final-jam-light(-annotated).png`, `36-final-gallery-dark(-annotated).png`.
- [`specs/current/contextual-bottom-bar.md`](contextual-bottom-bar.md) — Ready; current root navigation and contextual actions; partially superseded after this spec reaches `Ready`.
- [`specs/current/navigation-gallery-foundation.md`](navigation-gallery-foundation.md) — Ready; invariants preserved by this migration.
- [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) — app shell and dependencies.
- [`docs/DEVICE_VALIDATION.md`](../../docs/DEVICE_VALIDATION.md) — manual validation list.
- [`docs/TESTING.md`](../../docs/TESTING.md) — testing conventions.
- [`AGENTS.md`](../../AGENTS.md) — sources of truth and divergence protocol.

## Current Decision

**Increment 5A update — the native-tab direction is superseded.**
The production implementation no longer uses `TabView`, `UITabBar`,
or a native tab bar accessory for root navigation. The approved
result is a fully custom SwiftUI bottom navigation cluster:

```text
[ Gallery | Jam ]    [ camera ]
```

The document name remains unchanged for traceability. Historical
sections below that describe native tab-bar positioning are preserved
as rejected/obsolete context only; they are not authorization for new
implementation work.

### Increment 5A Final Architecture

- `ContentView` is the app shell and remains the single owner of
  root navigation state through `AppNavigationModel`.
- `AppTab` is the explicit persistent root-selection model:
  `.gallery` and `.jam` only. Capture is not an `AppTab`.
- Gallery and Jam each keep their own `NavigationStack` and path:
  `galleryPath` and `jamPath`.
- Both stacks remain mounted as siblings in a `ZStack`. The active
  stack gets `opacity(1)`, hit testing, accessibility, and higher
  `zIndex`; the inactive stack gets `opacity(0)`,
  `allowsHitTesting(false)`, and `accessibilityHidden(true)`.
- Root bottom navigation is inserted centrally with
  `safeAreaInset(edge: .bottom)`. Child screens do not apply local
  bottom compensation.
- `RootNavigationVisibility` remains the single derived visibility
  source. It hides the custom root navigation for detail routes and
  Capture presentation.

### Increment 5A Final Metrics

- Gallery/Jam capsule: 212 × 58 pt.
- Capture capsule: 88 × 58 pt.
- Cluster gap: 22 pt.
- Horizontal margin: 18 pt.
- Bottom padding inside the safe-area inset: 10 pt.
- No structural `offset`, `transformEffect`, trailing safe-area
  hacks, transparent spacers, or native-tab measurements are used.

### Increment 5A Capture Behavior

Capture remains an independent action in the custom cluster. Tapping
it calls the existing `beginCapture()` flow and presents the existing
Capture sheet. Cancel restores the previously selected tab. Complete
closes Capture, returns to Gallery, clears the Gallery path per the
existing product contract, and triggers the Gallery save reload path.

### Increment 5A Accessibility

- Gallery and Jam expose labels matching their titles and add the
  selected trait when active.
- Capture exposes label `Capture`, hint `Opens the camera`, and a
  88 × 58 pt touch target.
- The inactive root stack is hidden from accessibility.
- Selection animation is disabled when Reduce Motion is enabled.
- State is indicated by accent fill/stroke and selected trait, not
  color alone.

### Increment 5A Validation Record

Automated validation required for the final implementation:

- `git diff --check`
- Debug build on iPhone 17 Pro simulator
- Release build on iPhone 17 Pro simulator
- Relevant navigation/persistence tests

Manual visual validation required:

- Gallery dark and light mode
- Jam dark and light mode
- repeated Gallery ↔ Jam switching
- open/close Capture
- Gallery detail hides root navigation
- Jam editor/detail hides root navigation
- return preserves the previous tab/path where the product contract
  requires it

Screenshots captured for Increment 5A:

- `docs/audits/assets/custom-bottom-navigation/01-gallery-light.jpg`
- `docs/audits/assets/custom-bottom-navigation/02-jam-light.jpg`
- `docs/audits/assets/custom-bottom-navigation/03-jam-dark.jpg`
- `docs/audits/assets/custom-bottom-navigation/04-gallery-dark.jpg`
- `docs/audits/assets/custom-bottom-navigation/05-capture-sheet-dark.jpg`
- `docs/audits/assets/custom-bottom-navigation/06-gallery-detail-hidden-dark.jpg`
- `docs/audits/assets/custom-bottom-navigation/07-jam-editor-hidden-dark.jpg`

Known limitation: preservation of scroll position and visual centerY
alignment are validated manually because current tests cover the
navigation model, not rendered SwiftUI scroll geometry.

**Phase 0 is complete.** The spike ran in two rounds on branch
`spike/iphone-hybrid-tab-navigation` (closed after the report; **not
merged**). The report is
[`docs/audits/hybrid-tab-navigation-spike.md`](../../docs/audits/hybrid-tab-navigation-spike.md).
Round 1 established structural feasibility; Round 2 (reduced matrix)
resolved visual alignment and system glass and concluded **Result A —
Approved for production implementation**. The spike's answers are
incorporated under "Selected Implementation Decisions" below.

**Production implementation is authorized by this specification**,
starting at Increment 1 of the migration spec's Incremental Plan,
each increment on its own branch.

## Goal

Resolve the three open questions that block the migration spec's
successor from being promoted to `Ready`. All three are answered
based on iPhone behavior only:

1. **Positioning technique.** Which of the three techniques
   (shared container / `safeAreaInset` / `overlay`) works on
   iPhone without measuring the tab bar and without covering
   Jam.
2. **Visual padding values.** The trailing and bottom paddings
   that work on iPhone across portrait, landscape, and Dynamic
   Type without using any value that represents the presumed
   height of the system tab bar.
3. **Single-source-of-truth strategy.** Which of the three
   strategies keeps the selected root destination in a single
   place with no parallel state. The three strategies on the
   table are: (a) keep `AppNavigationModel.selectedDestination`
   and reinterpret it as the binding backing the `TabView`
   selection, (b) move the source to a dedicated
   `RootNavigationSelection` value type owned by the shell,
   (c) own the source in the app shell directly.

This specification is a Draft until the spike's evidence answers
all three questions and the answers are incorporated here.

## Phase 0 — Disposable Technical Spike

### Purpose

Produce evidence for the three questions above, based on iPhone
behavior. (Historical: while this specification was `Draft`, the
spike was the only work it authorized. The spike is complete; see
"Current Decision".)

### In Scope (spike may do)

- Create a separate, short-lived branch from the current
  `main` commit.
- Add a minimal demo shell with:
  - a `TabView` with two `Tab` values (Gallery, Jam) using
    placeholder content;
  - a `CaptureTabAccessory` (working name) candidate that follows
    the contract in the migration spec;
  - a toggle that hides and shows the native tab bar;
  - simulated detail screens (no real navigation, no real data);
  - a simulated `isPresentingCapture` toggle (no real sheet, no
    real camera, no real `PhotosPicker`).
- Test three positioning techniques in this order, recording
  evidence for each:
  1. shared bottom container (`ZStack(alignment: .bottomTrailing)`);
  2. `safeAreaInset(edge: .bottom)` applied to the container;
  3. `overlay(alignment: .bottomTrailing)`.
- Test on iPhone only:
  - iPhone portrait;
  - iPhone landscape;
  - Dynamic Type at the default size;
  - Dynamic Type at an enlarged size;
  - Dynamic Type at an accessibility size;
  - tab bar visible;
  - tab bar hidden;
  - Gallery selected;
  - Jam selected;
  - Capture button visible and tappable;
  - hit testing on and off the Capture button;
  - safe area changes during orientation;
  - light mode;
  - dark mode;
  - VoiceOver focus order;
  - Reduce Motion.
- When devices are available, also test on:
  - one iPhone with Dynamic Island;
  - one iPhone without Dynamic Island.
  Simulator is sufficient for the initial spike. A physical device
  may be used for the final implementation validation but is not
  required for Phase 0.
- Test the `TabView` selection binding against a
  `@State` value owned by the spike shell, and against an external
  source similar in shape to `AppNavigationModel.selectedDestination`,
  to gather evidence for the single-source-of-truth question.
- Take screenshots of every test. Annotate each screenshot with
  the iPhone model or simulator, the iOS version, the orientation,
  the Dynamic Type setting, the technique used, the padding used,
  the visibility state, and the hit testing target.
- Use a provisional accessibility identifier
  (`spike.captureAccessory`) so the spike's UI does not collide
  with the production identifier (`bottomBar.action.capture`).
- Iterate freely. The spike is disposable.

### Out Of Scope (spike must not do)

The spike must not:

- test, validate, or screenshot on iPad;
- adopt `tabViewStyle(.sidebarAdaptable)` or any sidebar-style
  layout;
- introduce abstractions whose only justification is iPad support;
- modify any file in `Dap/` beyond a self-contained demo file or
  folder clearly named under a spike prefix;
- modify `Dap/Features/Capture/CaptureView.swift`,
  `Dap/Features/Navigation/AppNavigationModel.swift`,
  `Dap/Features/Gallery/GalleryView.swift`, or any other currently
  live production file;
- remove, rename, or refactor `ContextualBottomBar`,
  `BottomBarPresentation`, `RootDestination`,
  `NavigationBarConfiguration`, or any related type;
- touch `PedalStore`, `CaptureViewModel`, `DapPipeline`, `DapSynth`,
  `CameraScreen`, or `AppIntentRouter`;
- add a third-party dependency;
- change the `IPHONEOS_DEPLOYMENT_TARGET`, `SWIFT_VERSION`, or
  toolchain;
- adopt Xcode 27 beta APIs or any `TabRole` outside the current
  baseline;
- connect to the real camera, real `PhotosPicker`, real pedal
  generation, real `PedalResultView`, real `Save Pedal`, real
  `Retake`, real `PedalboardsView`, or any real product flow;
- attempt to migrate the persistence layer, the audio engine, the
  music generation algorithm, or the Foundation Models metadata
  flow;
- open a PR against `main` or any long-lived branch;
- merge into `main`.

### Required Evidence

The spike must produce a report at
`docs/audits/hybrid-tab-navigation-spike.md`. The report uses three
categories, with the meaning of each defined as follows.

- **Observed.** The fact was directly measured or captured during
  the spike. Screenshots, code excerpts, and `xcrun simctl` output
  are evidence. The category does not claim the result is true on
  a physical device if the test was only on a simulator.
- **Inferred.** The fact is a reasonable conclusion drawn from
  observed evidence and from public API documentation, but the
  spike did not directly measure it. The category is explicit that
  physical-device validation is pending.
- **Not validated.** The fact was not measured by the spike. The
  report lists what would be required to validate it.

For each of the three positioning techniques, the report records:

- the iPhone model or simulator and the iOS version;
- the orientation;
- the Dynamic Type setting;
- the technique that was tested;
- the padding used (in points, trailing and bottom);
- the result (does it work without covering Jam, without
  displacing content, without a second bottom bar, with the
  accessory following safe area, in portrait and landscape, with
  the tab bar hidden, and visually close to the Figma);
- the reason for approval or rejection;
- screenshots;
- hit testing behavior, including the case where the trailing
  tab (Jam) is being tapped with the accessory visible;
- behavior when the tab bar is hidden by the toggle;
- the visual difference from the Figma composition.

For the single-source-of-truth question, the report records:

- the strategy tested in the spike;
- the result of binding the `TabView` selection to a `@State`
  value owned by the spike shell;
- the result of binding the `TabView` selection to an external
  source similar to `AppNavigationModel.selectedDestination`;
- the spike's recommendation.

For the visual padding question, the report records:

- the chosen trailing and bottom paddings for each technique
  tested;
- the iPhone model or simulator and orientation where the value
  was measured;
- the visual evidence (screenshot);
- the explicit statement that no padding value represents a
  presumed tab bar height.

For Dynamic Type, the report records:

- screenshots at the default size, an enlarged size, and an
  accessibility size, on iPhone;
- any failure or surprising behavior at the extremes.

For accessibility, the report records:

- VoiceOver focus order (Gallery, Jam, Capture);
- whether `Capture` is announced as a button, not a tab;
- the behavior with Reduce Motion enabled.

For the discard plan, the report confirms:

- the spike branch has been closed;
- the spike branch has not been merged.

A short note is appended to the report:

> iPad is outside the scope of this migration. A future
> specification must define iPad navigation and `Capture`
> placement before the app adopts an iPad-specific layout.

### Discard Plan

After the report is written, the spike branch is closed. The spike
code may be deleted, kept in an `archive/` folder for reference, or
squashed into a single commit for history. The spike is **not** the
starting point for production code. Production code begins from
`main` and follows the increment plan in the migration spec.

## Selected Implementation Decisions

Recorded from the Phase 0 spike's evidence and the product owner's
final visual decision (2026-07-20). These decisions supersede the
open alternatives in the migration spec.

### Positioning technique

**Shared container.** The `TabView` and the accessory are siblings
in a `ZStack(alignment: .bottomTrailing)` owned by the shell:

```swift
ZStack(alignment: .bottomTrailing) {
    TabView(...)
    CaptureTabAccessory(...)
}
```

`safeAreaInset` and `overlay` are visually equivalent and were not
needed as fallbacks. The public `tabViewBottomAccessory` API
(iOS 26.0+) was evaluated and rejected: it renders a full-width
accessory bar above the tab bar, not a trailing sibling of the
capsule.

### Accessory surface (glass)

**Blue luminous capsule under normal system glass — final decision:**

```swift
.glassEffect(
    .regular.interactive(),
    in: .capsule
)
```

The button uses `Image(systemName: "camera.fill")`, centered, with
no visible text label. The gradient language is blue photographic
light: deep blue, electric blue, cyan, contained white highlight,
darkened ends, and short contained glow. The gradient sits under
interactive regular Liquid Glass and remains visible through it.

Adjustable during production validation, globally only: exact width
within 112–132 pt, gap relative to the tab bar, beam placement, and
glow intensity.

Tested and rejected by visual direction (not the main
implementation; **not** an automatic fallback — retrievable only by
an explicit future product decision):

```swift
.glassEffect(
    .regular.tint(.accentColor).interactive(),
    in: .capsule
)
```

Rejection rationale: excessive chromatic emphasis; makes Capture
look visually separated from the tab bar; communicates more CTA
priority than desired; reduces coherence with the native
navigation material.

Also rejected: tinted-glass-only emphasis; `.buttonStyle(.glass)`
and `.buttonStyle(.glassProminent)` if they distort sizing;
`GlassEffectContainer` for this single accessory unless later
needed by measurement.

Increment 3 renders the button as:

```swift
Image(systemName: "camera.fill")
    .frame(width: 124, height: 58)
    .background { CaptureGradientBackground().clipShape(Capsule()) }
    .glassEffect(
        .regular.interactive(),
        in: .capsule
    )
```

preserving: Capture as a `Button`; no tab trait; opening Capture
without changing the selection; hit area restricted to the
control; visibility coordinated with the tab bar; return to the
previous tab after cancel or complete.

The implementation must not use: accent-color tint, manual
material, manual blur, custom shadow, artificial border,
`TabRole.search`, or `tabViewBottomAccessory` to reproduce the
trailing action.

### Visual positioning values

Baseline validated in the spike's base scenario (iPhone 17 Pro,
iOS 26.5, portrait, default Dynamic Type, light, Gallery, tab bar
visible; regression-checked on Jam and dark mode):

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

### CaptureTabAccessory visibility (product decision, 2026-07-20)

**Capture is a global creation action available from the root
surfaces. It is not available inside inspection, editing, detail,
or capture workflows.**

The accessory appears **only** on the main roots: Gallery root and
Jam root. It disappears when entering: Photo Inspector / pedal
detail, Pedalboard detail, the Capture flow (picker, camera,
processing, save retry, result), and any route that today derives
`BottomBarPresentation.hidden` — including any screen with
contextual actions such as Save Pedal or Retake.

Gallery and Jam remain the selected tabs even while the tab bar
and the accessory are hidden.

Hiding the accessory must not:

- change the selected tab;
- reset the `NavigationStack`;
- cancel a navigation;
- create parallel visibility state;
- depend on isolated offsets or opacity tricks.

### Single visibility source (product decision, 2026-07-20)

The native tab bar and the `CaptureTabAccessory` share one
visibility contract:

```swift
enum RootNavigationVisibility {
    case visible
    case hidden
}
```

Rule:

- root navigation visible → native tab bar visible →
  `CaptureTabAccessory` visible;
- root navigation hidden → native tab bar hidden →
  `CaptureTabAccessory` hidden.

The visibility value is **derived from the current route or
presentation**; it is never stored independently. The
implementation must not create: an independent
`isCaptureButtonVisible`; per-screen duplicated logic;
uncoordinated hide animations; or an accessory visible over a
screen whose tab bar is hidden.

### Visibility matrix (confirmed against `BottomBarPresentation` and the real routes, 2026-07-20)

| Surface | Tab bar | Capture accessory | Contextual actions |
| --- | --- | --- | --- |
| Gallery root | Visible | Visible | Hidden |
| Jam root | Visible | Visible | Hidden |
| Photo Inspector (pedal detail) | Hidden | Hidden | Per screen contract (today: `.hidden(.pedalDetail)`) |
| Pedalboard detail | Hidden | Hidden | Per screen contract (today: `.hidden(.pedalDetail)`) |
| Capture picker | Hidden | Hidden | Visible (Open Camera / Cancel) |
| Camera | Hidden | Hidden | Hidden (`.hidden(.camera)`) |
| Processing | Hidden | Hidden | Hidden (`.hidden(.processing)`) |
| Save Retry | Hidden | Hidden | Visible (Try Again / Discard) |
| Result | Hidden | Hidden | Visible (Save Pedal / Retake) |

This table was checked against
`Dap/Features/Navigation/AppNavigationModel.swift`
(`BottomBarPresentation.forNavigation` and `.captureFlow`) and the
routes in `Dap/Features/Capture/CaptureView.swift`; it
does not replace code investigation in later increments.

### Transitions (product decision, 2026-07-20)

- Opening the Photo Inspector: Gallery root → tab bar and Capture
  disappear together → the inspector occupies the surface.
- Returning: inspector → tab bar and Capture reappear together →
  Gallery and its previous state remain selected.
- The same rule applies to Jam and Pedalboard detail.
- The native API (`.toolbar(.hidden, for: .tabBar)`) hides the tab
  bar; the accessory observes the same `RootNavigationVisibility`
  state and transitions together.
- With Reduce Motion: a simple visibility change, no independent
  motion.

### Capture shape and emphasis

**Product review approved the Increment 3 direction on
2026-07-20.** Capture is a larger capsule-shaped global action with
a blue luminous gradient under interactive regular Liquid Glass.

Already decided and not reopened: Capture remains a
`Button`; remains separate from the tab bar; is not a tab; uses
public glass APIs; appears only on the roots; disappears in detail
and contextual flows.

Approved: capsule shape; `camera.fill`; blue luminous gradient
under `.glassEffect(.regular.interactive(), in: .capsule)`;
Gallery/Jam roots only. Adjustable after implementation evidence:
exact width, gap, beam placement, glow intensity, and final optical
alignment.

**Increment 1 is not blocked** (visual-neutral refactor).
**Increment 3 is authorized** by this approved visual direction.

### Single-source-of-truth strategy

`TabView(selection:)` binds to the **existing** selection source.
The implementation adapts `AppNavigationModel.selectedDestination`
to act as the binding that backs the `TabView` selection during
the early increments. **No parallel state is created.** Extraction
to a dedicated `RootNavigationSelection` value type happens only
if the implementation demonstrates a concrete need. Removal or
renaming of `AppNavigationModel.Destination` /
`selectedDestination` only happens in Increment 5 if the
implementation evidence shows the model has become redundant.

## Visual Differences vs. Figma

Recorded from the spike report (Round 2, "Remaining Differences
vs. Figma"):

1. **Surface.** The production accessory uses a blue luminous
   gradient under interactive regular Liquid Glass.
2. **Size.** The accessory starts at approximately 124×58 pt and
   may be tuned within 112–132 pt width during integration
   (globally, never per device).
3. **Gap.** The target visual gap between the tab bar capsule and
   Capture capsule is approximately 12–16 pt, tuned optically.
4. **Structure.** Capture is a SwiftUI `Button` sibling, not a
   system tab bar item. No public API on the baseline produces a
   non-tab action inside the bar; `tabViewBottomAccessory`
   produces a different composition and is rejected.
5. **Figma crop.** The cropped Figma reference could not be
   captured in the spike environment (HTTP 403). A reviewer with
   Figma access should attach it to the spike report; the visual
   decision above is final regardless.

## Manual Validation Items

Transferred from the spike to the production implementation. The
spike deliberately did not cover these; they belong to the
implementation's validation matrix. Status at promotion time:
`not run` for all items unless noted.

| Item | Status | Note |
| --- | --- | --- |
| Base scenario (iPhone 17 Pro, iOS 26.5, portrait, default DT, light, Gallery) | pass (spike) | alignment measured exact (821.8 pt centers) |
| Jam selected | pass (spike) | no overlap; alignment holds |
| Dark mode | pass (spike) | normal glass adapts with the tab bar |
| Dynamic Type enlarged | not run | production matrix |
| Accessibility sizes (AX3, AX5) | not run | spike Round 1 showed AX5 clips at the home indicator; production must fix via safe-area-aware positioning |
| VoiceOver (focus order, traits) | not run | accessory has label/hint/isButton; order inferred only |
| Reduce Motion | not run | no animation in the accessory so far |
| Landscape | not run | simulator did not rotate in the spike environment |
| Tab bar hidden (lockstep) | not run (production shape) | spike validated the toggle mechanism; production uses `TabBarVisibility` |
| iPhone without Dynamic Island | not run | no such simulator in the spike environment |
| Physical device | not run | simulator-only evidence |
| Automated hit testing | not run | must confirm `.offset(y:)` moves the hit area with rendering and that Jam stays tappable |
| Real Capture presentation (sheet) and contextual states | not run | spike used a simulated sheet |
| Light/dark beyond the regression checks | not run | production matrix |

## Preference Key Contract

`RootNavigationVisibility` (defined in Increment 1; the preference
key itself is introduced in Increment 3 when the accessory lands):

- An enum value `{ visible, hidden }` derived from the current
  route/presentation state — the single visibility source shared
  by the native tab bar and the `CaptureTabAccessory` (product
  decision, see "Single visibility source").
- Increment 1 introduces the type and derives it from
  `AppNavigationModel` (hidden when a detail route is on the path
  or the capture flow is presented; visible on the roots). No
  independent storage.
- Increment 2/3 wire the same value to
  `.toolbar(.hidden, for: .tabBar)` at the `NavigationStack`
  boundaries and to the accessory (via a small preference key or
  direct observation of the same model), so both surfaces
  transition together.
- Symmetric and deterministic: hiding root navigation hides both
  the tab bar and the accessory; showing it shows both. There is
  no independent visibility state for the accessory, no
  `isCaptureButtonVisible`, and no per-screen duplicated logic.
- Reduced to the smallest surface; removed together with the
  accessory in the removal plan.

## Documentation Updates

Scoped to the migration (performed in Increment 5 unless noted):

- `docs/ARCHITECTURE.md` — replace the custom-shell description
  with the `TabView` + `CaptureTabAccessory` shell; document the
  selection source and the `TabBarVisibility` key.
- `docs/TESTING.md` — add the hybrid-composition test conventions
  (selection-source tests, `tab.gallery` / `tab.jam` /
  `bottomBar.action.capture` identifiers, the transferred manual
  validation matrix above).
- `specs/current/contextual-bottom-bar.md` — mark the
  root-navigation sections as superseded following the
  `Superseded by` template in `specs/planned/gallery.md`; the
  contextual sections remain authoritative.
- `specs/planned/native-tab-navigation-migration.md` — remains
  `Draft` as the decision document until the migration reaches
  `Done` (already updated with the spike's decisions).

## Production Implementation — Increment Plan

The five-increment plan in
`specs/planned/native-tab-navigation-migration.md` is the reference
plan for production implementation. **Each increment is authorized
by this specification when started on its own branch.** The plan is
reviewed against the spike's evidence: no increment was shown unsafe
or unnecessary; Increment 3 adopts the decisions in "Selected
Implementation Decisions" (shared container, capsule Capture
accessory, blue luminous gradient under interactive regular Liquid
Glass, optical positioning, `RootNavigationVisibility` per the
contract above).

**Increment 3: Complete.** The `CaptureTabAccessory` is implemented
per the approved visual direction in this specification
(capsule, blue luminous gradient under interactive regular Liquid
Glass, optical positioning, sibling of the `TabView` in a
`ZStack(alignment: .bottomTrailing)`, visibility coordinated with
the tab bar via the single `RootNavigationVisibility` source).
Merged on the same branch as Increments 1 and 2.

**Increment 4: Complete.** Visibility and contextual bar
coordination. The single `RootNavigationVisibility` source drives
both the native tab bar (`.toolbar(.hidden, for: .tabBar)`) and
the `CaptureTabAccessory` together; the contextual bar inside the
capture sheet remains the only bottom surface during capture
phases. The accessory carries `.transition(.opacity)` to stay in
lockstep with the tab bar's native fade, and a defensive
`.contentShape(Capsule())` at the outermost view so the trailing
and bottom padding never extend the hit area beyond the visible
capsule. The redundant per-tab `.toolbar(.hidden, for: .tabBar)`
modifiers and the parallel `isShowingGalleryDetail` /
`isShowingJamDetail` properties were removed so the
`RootNavigationVisibility` value is the only switch.

**Increment 5 is not part of this step.** Removal of obsolete
infrastructure (`AppNavigationModel.Destination`,
`RootDestination`, `NavigationBarConfiguration`, the contextual
bar's `.navigation` case, the `bottomBar.destination.*`
identifiers) is deferred to a separate increment. The current
implementation does not yet demonstrate that those types are
redundant.

Increment 1 is complete in commit `66063380`
(`refactor(navigation): separate root navigation visibility`). It
was visually neutral, preserved the current bar, separated
root-navigation state from contextual state, preserved
`AppNavigationModel.selectedDestination`, and introduced the single
derived `RootNavigationVisibility` source without implementing the
new button or choosing circle vs. capsule.

Increment 2 is complete in commit `de9043b3`
(`feat(navigation): add native Gallery and Jam tabs`).
`TabView(selection:)` binds to `AppNavigationModel.selectedDestination`;
each `Tab` owns its own `NavigationStack`; Capture remained a
temporary non-tab trigger.

Increment 3 is complete in commit `f59cfc51`
(`feat(navigation): add Capture tab accessory`). Capsule
`CaptureTabAccessory` rendered as a sibling of the `TabView`,
wired to `beginCapture()`.

Increment 4 is complete on this branch. See the commit
`fix(navigation): coordinate root and contextual visibility` for
the coordination change and the commit
`docs(native-tab-navigation): record increment 4 validation` for
the documentation update.

The single-source-of-truth decision is recorded above: the
implementation adapts `AppNavigationModel.selectedDestination` as
the binding backing the `TabView` selection for the early
increments and removes or renames it in Increment 5 only if the
implementation evidence shows the model has become redundant.

### Increment 4 Validation Notes

- **Visibility matrix.** Confirmed against the
  `RootNavigationVisibility` contract: Gallery root, Jam root →
  visible; Photo Inspector, Pedalboard detail, all capture
  phases (picker, camera, processing, save retry, result) →
  hidden. The single value drives both the tab bar
  (`.toolbar(.hidden, for: .tabBar)`) and the `CaptureTabAccessory`
  (`if` on the same value). Covered by compiled-but-unexecuted
  tests
  `rootVisibilityMatrixIsConsistentForEverySurface` and
  `rootNavigationVisibilityIsTheSingleSourceForTabBarAndAccessory`
  in `DapTests/NavigationGalleryTests.swift`; these were not
  executed in this session because the focused `xcodebuild test`
  runner did not launch.
- **Transitions.** `beginCapture` flips a single boolean
  (`isPresentingCapture`) which the visibility source observes;
  there is no transient frame in which the tab bar is visible
  behind a capture sheet, and the accessory cannot appear or
  disappear out of step with the tab bar because both observe
  the same value. The per-frame ordering is enforced by
  SwiftUI's reaction to a single `RootNavigationState` change,
  not by two independent triggers. Covered by compiled-but-unexecuted
  test
  `noTransientTriggerBetweenSelectionAndRootVisibility`.
- **Hit testing.** The accessory's `.contentShape(Capsule())` is
  applied inside `CaptureTabAccessory` on the button label before
  the outer positioning padding, so the 8 pt trailing and 4 pt
  bottom visual padding do not become tappable. The outer
  `.contentShape(Capsule())` was removed during Dap rename
  reconciliation because it would have shaped the padded container
  instead of the visible capsule. The `.offset(y: 14)` is inferred
  to move the hit area with the rendering; no automated hit-test
  was added in this increment.
- **Path preservation.** Hiding the root navigation does not
  clear any per-tab path. `beginCapture`, `cancelCapture`, and
  `completeCapture` keep `galleryPath` and `jamPath` intact
  except for `completeCapture`'s existing product behaviour
  (clears `galleryPath`, selects Gallery). Covered by
  compiled-but-unexecuted test
  `hidingRootNavigationDoesNotClearNavigationPaths`.
- **No parallel visibility state.** The per-tab
  `.toolbar(.hidden, for: .tabBar)` modifiers and the
  `isShowingGalleryDetail` / `isShowingJamDetail` derived
  properties were removed. `RootNavigationVisibility` is the
  only switch; there is no independent accessory-visibility
  state and no per-screen duplicated logic.
- **Contextual bar.** Untouched. The contextual bar's
  `.contextual` and `.hidden` cases, identifiers, and
  `BottomBarPresentation` contract are preserved verbatim.
  Increment 4 only coordinates when it appears relative to
  root navigation; the sheet covers both the tab bar and the
  accessory during capture, leaving the contextual bar as the
  only bottom surface.
- **Test runner limitation.** The focused `xcodebuild test`
  attempt did not start `xctest` in this session (runner
  launch). Per the project's `AGENTS.md` Validation rule,
  validation fell back to `build-for-testing` (Debug and
  Release targets), Debug build, Release build, and static
  review. No `xctest` assertion was executed in this
  increment. Recorded as a runner/launch limitation, not an
  assertion failure.

### Increment 5A — Compact Capture Accessory (visual refinement)

**Goal:** retune the `CaptureTabAccessory` to match the Figma node
`121-1351` composition `[Gallery | Jam]    [camera.fill]`, where
the Capture capsule is a compact icon-only surface sitting next to
the native tab capsule with a 24 pt visual gap, instead of the
earlier wide 112 pt capsule.

#### Visual contract (final, 2026-07-20)

- Capture accessory:
  compact icon-only capsule based on Figma node `121-1351`.
- Symbol:
  `camera.fill` (20 pt, semibold, white).
- Gap:
  24 pt initial visual target. The gap emerges from the natural
  centering of the native tab capsule plus the 20 pt trailing
  margin of the accessory; no manual gap measurement.
- Width:
  64 pt. The 64 pt value targets the remaining trailing space
  after the native tab bar and the 24 pt visual gap on iPhone 17
  Pro. It is a single localized value inside the accessory, not a
  generic layout system. It stays outside the rejected 72–84 pt
  range and the rejected ~144 pt fixed width.
- Height:
  58 pt (matches the native tab capsule's visual height).
- Vertical alignment:
  `padding(.bottom, 4)` and `offset(y: 14)`, identical to
  Increment 3.
- Trailing alignment:
  `padding(.trailing, 20)` at the call site; the accessory
  inherits the ZStack's `bottomTrailing` alignment.
- Gradient:
  the central white highlight is softened (0.92 → 0.72) and the
  radial glow is softened (0.85 → 0.62, endRadius 46 → 34) so
  the `camera.fill` stays legible in the narrower frame.
- Glass:
  unchanged — `.glassEffect(.regular.interactive(), in: .capsule)`.

#### Native tab bar contract (must not be violated)

The native tab bar:

- must not be repositioned, resized, introspected, measured, or
  compensated;
- must stay exactly where the system positions it;
- must keep its full bounds, full hit area, and unmodified
  geometry.

The accessory adapts to the remaining trailing space around the
native tab bar; the native tab bar does not adapt to the
accessory.

#### Rejected approaches (preserved for traceability)

- Fixed Capture capsule near 144 pt: required manipulation of the
  native tab bar geometry (frame shrinking, safe-area insets,
  trailing ignores) or produced visual/interactive overlap with
  Jam. The visual was not viable without breaking the native tab
  bar's bounds, hit area, or centering.
- 72–84 pt fixed Capture capsule (intermediate exploration):
  produced a similar overlap problem at 72 pt and a hard-overlap
  with Jam at 84 pt on iPhone 17 Pro; replaced by the 64 pt
  compact accessory approved in node `121-1351`.
- `TabView.offset`, `transformEffect` on the `TabView` or on the
  `NavigationStack`s, narrow `TabView` frame, negative padding to
  compensate content, `safeAreaInset(edge: .trailing)` to move
  the tab bar, `ignoresSafeArea(.container, edges: .trailing)` on
  the `NavigationStack`s, `GeometryReader` to measure the tab
  bar, `UIScreen.main.bounds`, UIKit introspection, a constant
  representing the inner width of the tab bar, a transparent
  `Spacer` overlaid on Gallery or Jam, and hit-testing hacks to
  patch overlap: all rejected and not used.
- Mathematical centering of the two capsules as one cluster:
  rejected. The native tab capsule must keep its system-defined
  center; the accessory is anchored to the trailing area.

#### Diagnosis preserved from the prior spike attempt

The prior attempt on this increment demonstrated that, on the
current native tab API:

- the native TabView capsule remains centered in its own bounds;
- `safeAreaInset(edge: .trailing)` does not reposition the native
  capsule;
- shrinking the TabView's bounds compresses or clips the tab
  content;
- translating the TabView and compensating the `NavigationStack`s
  breaks the navigation chrome;
- a fixed ~144 pt Capture capsule does not fit next to the
  native capsule without overlap or without manipulating the
  private geometry of the TabView.

These findings are preserved to prevent re-exploring the same
rejected paths in future increments.

#### Visual validation (2026-07-20, iPhone 17 Pro simulator)

- Gallery, light mode: pass — capsule is 64×58 pt, gap ≈ 24 pt,
  icon centered, no overlap.
- Gallery, dark mode: pass — gradient and glass adapt, icon
  legible, no overlap.
- Jam uses the same ZStack structure, so the visual is identical
  by construction; the Jam tab remains fully tappable, including
  the trailing region, because the accessory's `.contentShape(
  Capsule())` is applied inside `CaptureTabAccessory` before the
  outer positioning padding, matching the Increment 4 contract.
- Navigation title, toolbar, and navigation chrome are unmodified;
  the navigation stack is not transformed, offset, or padded to
  compensate the accessory.
- The accessory is hidden on detail screens and during the
  Capture flow via the same `RootNavigationVisibility` source
  established in Increment 4.

#### Commits

- `fix(navigation): refine compact Capture accessory` — the
  implementation commit.
- `docs(native-tab-navigation): record compact accessory decision`
  — this documentation commit.

## Acceptance Criteria for Phase 0 Completion

Phase 0 is complete when:

- the spike branch has been created, used, and is ready to be
  discarded;
- the report at `docs/audits/hybrid-tab-navigation-spike.md`
  exists, uses the `Observed` / `Inferred` / `Not validated`
  format, and answers the three questions in the `Goal` section
  above with at least one item per category per question;
- the report's screenshots cover iPhone portrait, iPhone
  landscape, the default Dynamic Type, an enlarged Dynamic Type,
  an accessibility Dynamic Type, and the tab bar hidden state,
  for at least one positioning technique that the report
  recommends;
- the report explicitly distinguishes simulator evidence from
  physical-device evidence. If a physical device was not
  available, the report says so;
- the report's "iPad is outside the scope" note is present;
- the spike branch is closed. The branch is not merged.

## Acceptance Criteria for Promoting This Spec to Ready

This specification can be promoted from `Draft` to `Ready` (or `In
Progress`) only when **all** of the following are true:

1. The Phase 0 spike has been completed and its report exists at
   `docs/audits/hybrid-tab-navigation-spike.md`.
2. The report answers the three questions in the `Goal` section:
   positioning technique chosen, visual padding values chosen,
   single-source-of-truth strategy chosen.
3. The chosen positioning technique, the chosen paddings, and the
   chosen single-source-of-truth strategy are recorded in this
   specification under "Selected Implementation Decisions" (a new
   section added when the spec is promoted to `Ready`).
4. The migration spec's `Open Questions` section has been updated
   to mark each of the three questions as resolved, with a pointer
   to the spike's report.
5. The visual differences between the Figma composition and the
   spike's recommended composition are documented in this
   specification under "Visual Differences vs. Figma" (a new
   section added when the spec is promoted to `Ready`).
6. The five-increment plan in the migration spec has been reviewed
   against the spike's evidence. The plan is updated if the spike
   showed that any increment is unsafe or unnecessary.
7. The manual validation items for iPhone are listed in this
   specification under "Manual Validation Items" (a new section
   added when the spec is promoted to `Ready`). Items that the
   spike did not cover are listed as `not run` with a brief
   reason.
8. The contextual action identifiers and the contextual bar
   contract have been re-checked against the migration spec and
   are confirmed to be preserved.
9. The `TabBarVisibility` preference key's contract is defined in
   this specification under "Preference Key Contract" (a new
   section added when the spec is promoted to `Ready`).
10. The spike branch has been closed. The branch is not merged.
11. The `docs/ARCHITECTURE.md` and `docs/TESTING.md` updates
    required by the migration are listed in this specification
    under "Documentation Updates" (a new section added when the
    spec is promoted to `Ready`).
12. The "iPad is outside the scope of this migration" note is
    preserved in this specification.

## Open Questions

- Figma frame copy: `Biblioteca` vs. `Gallery`. This question
  does not depend on the spike; it is a product decision.
- ~~Visual padding values for the accessory (iPhone only).~~
  Resolved: trailing 12, bottom 4, optical `offset(y: 14)` — see
  "Selected Implementation Decisions".
- ~~Positioning technique chosen (iPhone only).~~ Resolved: shared
  container — see "Selected Implementation Decisions".
- ~~Single-source-of-truth strategy chosen.~~ Resolved: adapt
  `AppNavigationModel.selectedDestination`, no parallel state —
  see "Selected Implementation Decisions".
- Future `TabRole.prominent` decision (out of scope for now).

## Next Steps

1. ~~Run the Phase 0 spike on a short-lived branch.~~ Done
   (branch `spike/iphone-hybrid-tab-navigation`; closed, not
   merged).
2. ~~Write the report at `docs/audits/hybrid-tab-navigation-spike.md`
   with the `Observed` / `Inferred` / `Not validated` format.~~
   Done (two rounds).
3. ~~Incorporate the spike's answers into this specification and
   into the migration spec's `Open Questions` section.~~ Done.
4. ~~Promote this specification to `Ready` when the acceptance
   criteria above are satisfied.~~ Done (2026-07-20).
5. Execute production implementation in the increments defined
   in the migration spec, starting at Increment 1 on branch
   `codex/native-tab-navigation-implementation`, reporting each
   manual validation item as `pass` / `fail` / `not run`.
