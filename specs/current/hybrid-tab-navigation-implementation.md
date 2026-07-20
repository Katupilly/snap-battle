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
> `Done`. The approved visual uses **normal glass**
> (`.glassEffect(.regular.interactive(), in: .circle)`), not a
> tinted surface.
>
> File paths in this document were updated to the post-rename
> layout (`snap-battle/`).

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
- modify any file in `snap-battle/` beyond a self-contained demo file or
  folder clearly named under a spike prefix;
- modify `snap-battle/Features/Capture/CaptureView.swift`,
  `snap-battle/Features/Navigation/AppNavigationModel.swift`,
  `snap-battle/Features/Gallery/GalleryView.swift`, or any other currently
  live production file;
- remove, rename, or refactor `ContextualBottomBar`,
  `BottomBarPresentation`, `RootDestination`,
  `NavigationBarConfiguration`, or any related type;
- touch `PedalStore`, `CaptureViewModel`, `PhotoPedalPipeline`, `PhotoPedalSynth`,
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

**Normal system glass — final decision:**

```swift
.glassEffect(
    .regular.interactive(),
    in: .circle
)
```

Tested and rejected by visual direction (not the main
implementation; **not** an automatic fallback — retrievable only by
an explicit future product decision):

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

Also rejected: `Circle` + tint; `.buttonStyle(.glass)` and
`.buttonStyle(.glassProminent)` (intrinsic sizing overflows the
56×56 frame and clips); `GlassEffectContainer` (no effect for a
single element).

Increment 3 renders the button as:

```swift
Image(systemName: "camera.fill")
    .frame(minWidth: 56, minHeight: 56)
    .glassEffect(
        .regular.interactive(),
        in: .circle
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
`snap-battle/Features/Navigation/AppNavigationModel.swift`
(`BottomBarPresentation.forNavigation` and `.captureFlow`) and the
routes in `snap-battle/Features/Capture/CaptureView.swift`; it
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

### Capture shape and emphasis (gate)

**Product review required before Increment 3.** The circular
format recorded above is the spike's validated baseline, not an
immutable final contract: a larger capsule-shaped Capture action
(with more width, glass, possible color or gradient, and more
visual weight to balance the tab bar) is under product
evaluation.

Already decided (not reopened by the review): Capture remains a
`Button`; remains separate from the tab bar; is not a tab; uses
public glass APIs; appears only on the roots; disappears in detail
and contextual flows.

Pending visual decision: circle or capsule; final width; normal
glass, tinted glass, or gradient composition; `camera.fill` or
another symbol combination; final gap relative to the
Gallery/Jam capsule.

**Increment 1 is not blocked** (visual-neutral refactor).
**Increment 3 is blocked** until the visual direction is approved,
because it introduces the definitive accessory.

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

1. **Tint (intentional divergence).** The Figma frame suggests a
   tinted Liquid Glass surface. The final product decision
   overrides this: normal glass is the approved surface so Capture
   belongs to the tab bar's visual family instead of reading as a
   colored CTA. This is a product decision, not a technical
   limitation.
2. **Size.** The accessory is 56×56 pt; the Figma frame sizes
   Capture to the tab bar's intrinsic item size. 56 pt keeps a
   comfortable hit area and may be tuned during integration
   (globally, never per device).
3. **Gap.** 40 pt between the capsule's trailing edge and the
   accessory's leading edge at trailing 12 pt.
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
Implementation Decisions" (shared container, normal glass,
12/4/offset-14 baseline, `RootNavigationVisibility` per the contract
above).

**Increment 3 is blocked until the Capture shape/emphasis visual
review is approved** (see "Capture shape and emphasis (gate)").
Increments 1, 2, 4, and 5 are not blocked by that review.

Increment 1 is complete in commit `66063380`
(`refactor(navigation): separate root navigation visibility`). It
was visually neutral, preserved the current bar, separated
root-navigation state from contextual state, preserved
`AppNavigationModel.selectedDestination`, and introduced the single
derived `RootNavigationVisibility` source without implementing the
new button or choosing circle vs. capsule.

Increment 2 is authorized next: introduce the native `TabView` for
Gallery and Jam, bind it to `AppNavigationModel.selectedDestination`,
preserve contextual actions, keep Capture as a temporary non-tab
trigger until Increment 3, and do not implement the final
`CaptureTabAccessory`.

The single-source-of-truth decision is recorded above: the
implementation adapts `AppNavigationModel.selectedDestination` as
the binding backing the `TabView` selection for the early
increments and removes or renames it in Increment 5 only if the
implementation evidence shows the model has become redundant.

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
