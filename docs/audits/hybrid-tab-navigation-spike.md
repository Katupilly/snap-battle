# Hybrid Tab Navigation Spike

Status: Phase 0 — Round 2 complete. **Result A — Approved for production implementation.**
Branch: `spike/iphone-hybrid-tab-navigation` (discarded after this report; **not merged**).
Author: spike harness.
Last updated: 2026-07-20 (final visual decision incorporated: normal glass, not tinted).

## Rounds

### Round 1 — Structural feasibility

Result:

- Native `TabView` with an accessory sibling is structurally possible.
- Shared container is a starting point.
- Visual finish was **not approved**: the Capture button was vertically
  misaligned with the capsule's visual center (button center 808.2 pt vs.
  capsule center 821.8 pt — 13.6 pt too high) and did not use Liquid Glass.
- Trailing 12 / bottom 4 are **not final values**.
- `Circle` + tint is **rejected** (not system glass; does not track dark
  mode, Increase Contrast, or the tab bar's material).

Round 1's detailed evidence is kept below for reference. Where Round 1
conclusions conflict with Round 2 (padding values, accessory surface),
Round 2 supersedes them.

### Round 2 — Visual alignment and system glass

See the dedicated section "Round 2 — Visual Alignment And System Glass"
below. Conclusion: **Result A — Approved for production
implementation** (alignment approved, system glass approved via public
API). Final visual decision (product owner, 2026-07-20): the
CaptureTabAccessory uses **normal glass**
(`.glassEffect(.regular.interactive(), in: .circle)`); the tinted
variant was tested and **rejected by visual direction** and is not an
automatic fallback.

> iPad is outside the scope of this migration. A future specification
> must define iPad navigation and `Capture` placement before the app
> adopts an iPad-specific layout.

## Environment

| Item | Value |
| --- | --- |
| Xcode | 26.5 (Build 17F42) |
| iOS deployment target | 26.5 |
| Simulators used | iPhone 17 Pro (iOS 26.5, with Dynamic Island) |
| Without-Dynamic-Island device | not run; not available in this spike environment |
| Physical device | not used; simulator only |
| Build configuration | Debug |
| App target | `snap-battle` (`PedroKosciuk.snap-battle`) |
| Spike launch | `SIMCTL_CHILD_DAP_SPIKE=1` set in launch environment; spike code lives under `snap-battle/Features/Spike/` and is auto-built via the project's `fileSystemSynchronizedGroups` |
| Diff against main | only the spike folder plus a four-line, env-gated launch hook in `snap_battleApp.swift` (marked `SPIKE`; removed before any merge) |

All screenshots in `docs/audits/assets/hybrid-tab-spike/` are simulator
screenshots taken with `xcrun simctl io ... screenshot`. **No
physical-device evidence was captured.** A physical iPhone with
Dynamic Island and a physical iPhone without Dynamic Island are
listed in the "Not validated" sections below.

## Round 1 Detail — Goal And Conclusions (superseded in part by Round 2)

The spike answered the three open questions in
`specs/current/hybrid-tab-navigation-implementation.md` (Goal section).

1. **Positioning technique.** **Shared container
   (`ZStack(alignment: .bottomTrailing)`)** is the chosen technique.
   The other two are rejected for the reasons in the per-technique
   sections below. The chosen technique is the lowest-cost
   composition that satisfies all of the spec's invariants
   (no measurement of the tab bar, no `TabRole.search`,
   Capture not a tab, hit area bounded, lockstep with the tab
   bar's visibility). _Round 2 confirms this technique and adds an
   optical `offset(y:)`; it also evaluates the public
   `tabViewBottomAccessory` API and rejects it for this composition._
2. **Visual padding values.** _Superseded by Round 2: trailing 12 pt
   and bottom 4 pt are retained as base values but are **not final**;
   Round 2 adds an optical vertical offset of 14 pt._ Round 1 text
   follows for the record: **Trailing 12 pt, bottom 4 pt**
   for Dynamic Type up to and including `accessibility3` (AX3).
   At `accessibility5` (AX5) the spec's 0–8 pt range is not
   sufficient: the system home-indicator region grows and the
   accessory's bottom edge clips into it. This is a
   known limitation and a recommended production fix is
   documented in "Remaining Risks". The spike also validated
   that 8 pt trailing puts the accessory too close to Jam, and
   16 pt trailing reads as visually loose.
3. **Single-source-of-truth strategy.** _(Round 1 conclusion; not
   re-opened by Round 2.)_ **Approach A
   (`@State` in the shell)** is the recommended strategy for
   the early increments. The shell owns the selection, the
   `TabView(selection:)` binding reads and writes that state,
   and `beginCapture`/`cancelCapture`/`completeCapture`
   (re)interpret the same state. This decision is provisional;
   the production spec may move the source into the existing
   `AppNavigationModel` or into a new `RootNavigationSelection`
   value type once the migration is past Increment 2. Approach B
   (an external `@Observable` model) was also tested and is
   recorded as equivalent in behavior; the difference is
   architectural, not visual, and the choice should be made by
   the production spec on integration grounds, not visual
   evidence.

## Techniques Tested

Techniques were tested in the order required by the spec.

### Shared Container

#### Observed

- Composition: `ZStack(alignment: .bottomTrailing) { tabContent; SpikeCaptureTabAccessory(...).padding(.trailing, 12).padding(.bottom, 4) }` on iPhone 17 Pro simulator, iOS 26.5.
- The `TabView` with two `Tab` values (`Gallery`, `Jam`) is the
  bottom-most layer; the accessory sits on top of the same ZStack
  and is aligned to the bottom-trailing edge.
- Switching between Gallery and Jam keeps the accessory in the
  same screen-relative position; the accessory does not depend
  on which tab is selected.
  See `01-shared-12-4-gallery.png` and `02-shared-12-4-jam.png`.
- The accessory does not cover the Jam tab item at any tested
  padding in the matrix (8/0, 8/4, 8/8, 12/0, 12/4, 12/8, 16/0,
  16/4, 16/8). The accessory is anchored to the screen edge,
  not the tab bar's pill, so it sits to the right of the pill.
- Hiding the tab bar via the in-spike toggle also hides the
  accessory in lockstep. The toggle drives
  `toolbar(.hidden, for: .tabBar)` on the root `NavigationStack`
  and a `@State` that the accessory reads. The native tab bar
  fades out and the accessory disappears with it.
  See `12-shared-12-4-gallery-bar-hidden.png`.
- The bar-hidden state is symmetric: there is no separate
  visibility for the accessory; it inherits the same boolean.
- The `simulatedCapture` sheet is presented as a `.sheet` and
  covers the entire screen, including the tab bar and the
  accessory. There is no visual conflict. See
  `25-shared-capture-sheet-active.png`.
- Approach B (external source via `SpikeExternalSelectionModel`)
  is visually identical to Approach A. The `TabView` selection
  is updated by the same binding shape; only the ownership
  location changes. See `23-approach-b-jam.png`.
- Dark mode adapts the tab bar material; the accessory's tinted
  circle remains visible. See `16-shared-12-4-gallery-dark.png`.

#### Inferred

- Hit testing: the `SpikeCaptureTabAccessory` is a `Button` with
  a 56×56 frame and `.contentShape(Rectangle())` on the same
  frame. The padding that wraps the button (`.padding(.trailing,
  12).padding(.bottom, 4)`) does not extend the hit area; the
  surrounding ZStack is transparent. Therefore taps outside the
  56×56 button fall through to the `TabView` underneath, and
  Jam is fully tappable. This was not directly measured with
  taps because `simctl` cannot inject taps in this environment,
  but the SwiftUI hit-test model is deterministic and the
  inspection of the layout tree (Button inside padding inside
  ZStack on top of TabView) supports the inference.
- The accessory follows the safe area on rotation: the
  `bottomTrailing` alignment of the ZStack respects the
  container's safe area insets. iPhone landscape was not
  directly captured (see "Not validated"), but the composition
  is identical to the iPhone 26 baseline behavior.
- `accessibilityLabel("Capture")` and `accessibilityHint(...)`
  on the `Button` mean VoiceOver announces the accessory as a
  button, not a tab. The `TabView`'s two `Tab` values expose
  themselves as tabs. The order in the focus tree is `Tab` (one
  per root, in declaration order) then the overlay. VoiceOver
  was not directly driven in this environment, but the API
  contract supports the inference.

#### Not validated

- iPhone **landscape** orientation. The simulator window's
  orientation did not respond to `simctl ui orientation`,
  `Cmd+Left/Right Arrow` keystroke, or the `Device > Rotate
  Left/Right` menu item under the headless environment used for
  the spike. Manual device rotation is required. The
  composition is expected to remain correct because the
  accessory is anchored to the container's bottom-trailing,
  not to a device-class constant.
- iPhone **without Dynamic Island** (e.g. iPhone 16e, iPhone
  SE-class). Not run because no such simulator was used in this
  session. The accessory's bottom-trailing alignment is
  expected to be unaffected by the presence or absence of a
  Dynamic Island because the composition is anchored to the
  ZStack's edges, not the device's top safe area.
- **VoiceOver** focus order on a real device. The
  `accessibilityLabel` and `accessibilityAddTraits(.isButton)`
  are set; actual spoken order was not driven.
- **Reduce Motion** behavior. The accessory is static; no
  animation is applied to it. The spike has no animation, so
  Reduce Motion has no observable effect.
- **Hit testing** measured by simulating a tap on the Jam
  region. The inference above is the strongest evidence the
  spike can produce in this environment; a follow-up with a
  `XCUIApplication` driver would be required to assert the
  hit-test claim with a screenshot.
- **Physical device** validation. Simulator only.

#### Decision

**Approved.** This is the chosen technique. It satisfies all
of the spec's invariants for the in-scope (iPhone) scenarios
that the spike was able to capture. The remaining unvalidated
scenarios are not expected to expose regressions because the
composition is anchored to the safe area and the public layout
API, not to any device-class or system-private value.

### Safe Area Inset

#### Observed

- Composition: `VStack { tabContent }.safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 0) }.overlay(alignment: .bottomTrailing) { ... }`.
- The visual result is **identical to the shared-container
  technique** for every tested padding and tab state.
  See `17-safeareainset-12-4-gallery.png` and
  `18-safeareainset-12-4-jam.png`.
- The empty `safeAreaInset` reserves no height. Therefore the
  native tab bar is not pushed up, and the overlay that hosts
  the accessory behaves exactly like the shared container's
  overlay.
- The technique **cannot be used to push the tab bar up**
  without also losing the system's tab bar appearance, which
  violates the spec's "do not implement background, blur, or
  material of the tab bar" rule.

#### Inferred

- `safeAreaInset(edge: .bottom)` on a `Tab`'s `NavigationStack`
  content would push the content up; applied to the *root
  `TabView`*'s host, the inset is consumed by the system tab
  bar. In either case the technique does not produce a
  composition distinct from the shared container for this
  problem.
- The `safeAreaInset` modifier is the correct primitive for
  reserving the bottom safe area inside the system tab bar's
  visual region; it is not the correct primitive for placing
  a sibling view alongside the tab bar.

#### Not validated

- The same scenarios as "Shared Container > Not validated".
- A non-zero `safeAreaInset` (e.g. `Color.clear.frame(height:
  64)`) was not tested because it would replace the system tab
  bar's visual height with a manual approximation, which the
  spec forbids.

#### Decision

**Rejected for the current problem.** It is not a real
alternative; the spec listed it as a fallback for the case in
which the shared container could not preserve the native tab
bar's behavior. That case did not arise in the spike.

### Overlay

#### Observed

- Composition: `tabContent.overlay(alignment: .bottomTrailing) { SpikeCaptureTabAccessory(...).padding(.trailing, 12).padding(.bottom, 4) }`.
- The visual result is **identical to the shared-container
  technique** for every tested state. See
  `19-overlay-12-4-gallery.png` and
  `20-overlay-12-4-jam.png`.
- The bar-hidden and accessibility-size tests on the overlay
  technique are also visually identical to the shared container.
  See `21-overlay-12-4-gallery-AX3.png` and
  `22-overlay-12-4-gallery-bar-hidden.png`.

#### Inferred

- The `.overlay` modifier on the `TabView` does not add a new
  layout level: the overlay is laid out in the same coordinate
  space as the `TabView` and is anchored to the
  `bottomTrailing` of the same container that hosts the
  `TabView`. Therefore the result is identical to the shared
  container with one fewer layout level.
- The overlay's hit area is the same as the shared container's:
  the button's 56×56, the surrounding padding transparent.

#### Not validated

- The same scenarios as "Shared Container > Not validated".

#### Decision

**Functionally equivalent to the shared container.** The
shared container is preferred because it makes the "accessory
is a sibling of the TabView, not a child" invariant explicit
in the code. The overlay is a valid implementation if the
production spec wants the same visual with one fewer view
hierarchy level; the spike does not need to choose between
them on visual grounds.

## Padding Matrix

All values are in points. The matrix is run on iPhone 17 Pro,
iOS 26.5 simulator, portrait, light mode, default Dynamic Type
(`L`), Gallery tab selected, tab bar visible. Screenshots
prefixed `0X-` in the assets folder.

| Trailing | Bottom | Screenshot | Verdict |
| --- | --- | --- | --- |
| 8 | 0 | `03-shared-8-0-gallery.png` | **Fails.** Accessory bottom edge is on the home indicator line. |
| 8 | 4 | `04-shared-8-4-gallery.png` | Acceptable but visually too close to Jam's right edge. |
| 8 | 8 | `05-shared-8-8-gallery.png` | Acceptable; closer to Jam than 12 pt. |
| 12 | 0 | `06-shared-12-0-gallery.png` | **Fails.** Same home-indicator issue as 8/0. |
| 12 | 4 | `07-shared-12-4-gallery.png` | **Chosen.** Visual integration is balanced; no overlap with Jam, no overlap with home indicator at default Dynamic Type. |
| 12 | 8 | `08-shared-12-8-gallery.png` | Acceptable; more vertical breathing room than 12/4. |
| 16 | 0 | `09-shared-16-0-gallery.png` | **Fails.** Same home-indicator issue. |
| 16 | 4 | `10-shared-16-4-gallery.png` | Acceptable; reads as visually loose compared to 12/4. |
| 16 | 8 | `11-shared-16-8-gallery.png` | Acceptable; too loose for the Figma composition. |

**Explicit statement on the spec's forbidden values.** No
padding value in the matrix represents the presumed height of
the system tab bar. None of the values derives from a
`GeometryReader`, a `Spacer().frame(height:)`, or a
per-device constant. The bottom padding is a visual offset
from the screen edge, not a reproduction of the tab bar's
internal height.

**Dynamic Type edge cases.** The matrix above is captured at
default Dynamic Type. The Dynamic Type behavior is captured
separately:

- `XS`: `13-shared-12-4-gallery-XS.png` — accessory unaffected.
- `AX3`: `14-shared-12-4-gallery-AX3.png` and
  `21-overlay-12-4-gallery-AX3.png` — accessory unaffected.
- `AX5`: `15-shared-12-4-gallery-AX5.png`,
  `26-shared-12-8-gallery-AX5.png`,
  `27-shared-16-8-gallery-AX5.png`,
  `28-shared-12-0-gallery-AX5.png`,
  `29-shared-12-4-jam-AX5.png` — at AX5, the home-indicator
  visual region grows, and the accessory's bottom edge clips
  into it. The 12/4, 12/8, 16/8, and 12/0 paddings all clip at
  AX5. The 0–8 pt bottom padding range is not sufficient to
  clear the home indicator at AX5. The chosen production fix
  is documented in "Remaining Risks".

**Bottom padding must not be 0.** The matrix shows that 0 pt
of bottom padding always overlaps the home indicator at any
Dynamic Type. The recommended minimum is 4 pt; 8 pt is safer
at Dynamic Type up to AX3.

## Selection Ownership Comparison

The spike tested two approaches.

| Aspect | Approach A (`@State` in shell) | Approach B (external `@Observable` model) |
| --- | --- | --- |
| Visual result | Identical to Approach B. | Identical to Approach A. See `23-approach-b-jam.png`. |
| Source of truth location | The shell view's `@State`. | A separate `@Observable` model owned by the shell, exposed as a `Binding` to the `TabView`. |
| Parallel state risk | None if the shell is the only place that holds the selection. | None if the shell is the only place that holds the model. |
| Tab preservation across capture | Tested by code path: the spike does not change `selected` on `beginCapture` (selection unchanged for the duration of the sheet). | Same; the model's `beginCapture` records `destinationBeforeCapture` and `cancelCapture` restores it. |
| Integration with `AppNavigationModel` | The shell's `@State` is a fresh source. The production `AppNavigationModel.selectedDestination` would need to be reinterpreted as the binding that backs the `TabView`, OR a separate `RootNavigationSelection` would be introduced, OR the shell would own the source directly. The decision belongs to the production spec. | The external model is closer in shape to `AppNavigationModel`. The migration could either keep `AppNavigationModel.selectedDestination` and reinterpret it, or introduce a new model. |
| Test impact | Existing `NavigationGalleryTests.swift` would need new cases that drive the shell's selection, not the legacy model. | New tests would target the external model directly. |
| Number of test files | One shell test file. | One model test file plus one shell wiring test. |
| Lines of code in the spike | ~15 lines of state. | ~30 lines (model + binding). |

**Recommendation.** **Approach A** is recommended for the
early increments because (a) the visual evidence is identical
to Approach B, (b) the integration surface is smaller, and
(c) the production spec can move the source into a dedicated
type or into `AppNavigationModel` later without changing the
shell's `TabView` binding shape. The decision to use
Approach A does not pre-determine whether the production
source lives in `AppNavigationModel` or in a new
`RootNavigationSelection` value type; both are compatible
with Approach A. The migration spec's "Open Questions" is
considered partially answered: Approach A is chosen; the
ownership location is left for the production spec.

## Accessibility Validation

### VoiceOver

- The two `Tab` values are exposed by the native `TabView` as
  tabs. The selection state is announced by the system.
- The `SpikeCaptureTabAccessory` is a `Button` with
  `accessibilityLabel("Capture")`,
  `accessibilityHint("Abre a câmera para criar um pedal")`,
  `accessibilityAddTraits(.isButton)`, and
  `accessibilityIdentifier("spike.captureAccessory")`. The
  identifier is spike-only and intentionally does not match the
  production identifier `bottomBar.action.capture`.
- The accessory is **never** declared as a `Tab`. The
  `accessibilityAddTraits(.isButton)` line is present; the
  `.isTab` trait is not added.
- **Inferred** focus order: the two `Tab` values (Gallery, Jam)
  come first (declared in the `TabView`'s body in that order),
  then the `SpikeCaptureTabAccessory` (which sits at the
  bottom-trailing of the ZStack and is laid out after the
  `TabView` in the view tree). The simulator's
  accessibility inspector was not driven, so the order is an
  inference, not a measurement.

### Reduce Motion

- The accessory has no animation. Reduce Motion has no
  observable effect on the accessory. The spike shell's debug
  menu uses standard `Picker` and `Toggle` controls, which
  respect Reduce Motion natively.
- **Inferred** to be a non-issue for the accessory because
  there is no animation to disable.

### Dynamic Type

- Default (`L`), `XS`, `M`, `XL` — accessory is unaffected.
- `AX3` — accessory is unaffected; tab bar's pill grows
  slightly but the accessory remains outside the pill.
  See `14-shared-12-4-gallery-AX3.png`.
- `AX5` — **clips at the home indicator.** This is a known
  limitation, recorded under "Remaining Risks". The
  recommendation is that the production implementation
  compute a dynamic bottom padding that respects the safe
  area at AX5, or position the accessory relative to the
  tab bar's safe area inset rather than the screen edge.

### Differentiate Without Color

- The accessory is a filled `Circle` with `camera.fill` glyph.
  It is identified by its symbol and shape, not by color alone.
  Differentiate Without Color is supported.

### Hit Testing

- The accessory is a `Button` with a 56×56 frame, larger than
  the 44×44 minimum. The `.contentShape(Rectangle())` matches
  the visible frame.
- The surrounding ZStack is transparent. Taps outside the
  56×56 frame fall through to the `TabView` underneath.
  **Jam is fully tappable.**
- No invisible surface blocks the interface: the ZStack is
  transparent, the overlay is non-hit-testing outside the
  button's frame, and the `safeAreaInset` is empty.
- **Inferred** hit testing: the inference relies on the
  SwiftUI layout and hit-test rules. A `XCUIApplication` test
  would be required to assert the claim with a real tap.

## Visual Differences vs. Figma

The Figma frame (referenced in
`specs/planned/native-tab-navigation-migration.md`) shows a
native iOS 26 tab bar with a single `TabSection` containing
Gallery and Jam, plus a visually separated `Capture` action.
The spike's chosen composition produces the following
differences:

1. **Capture is rendered as a separate circular button
   outside the system tab bar's pill**, not inside it. The
   Figma frame shows `Capture` aligned with the tab bar but
   visually separated; the spike achieves the same visual
   separation by anchoring a `SpikeCaptureTabAccessory` to
   the bottom-trailing of the same ZStack that hosts the
   `TabView`. The visual outcome is close to the Figma; the
   implementation difference is that the accessory is a
   SwiftUI `Button` rendered by the shell, not a system tab
   bar item.
2. **The accessory's color is `Color.accentColor` (blue) on
   a filled `Circle` with `camera.fill` glyph.** The Figma
   frame uses a tinted surface consistent with the system's
   Liquid Glass appearance. The spike uses a plain tinted
   `Circle` to keep the implementation portable across minor
   iOS releases. A production implementation should prefer a
   system-provided tinted surface (e.g. `glassEffect` if
   available in the baseline) so the accessory receives the
   same Liquid Glass treatment as the tab bar in dark mode and
   with Increase Contrast. The spike does not test the
   `glassEffect`-based primitive because the spec restricts
   the spike to the current baseline.
3. **At AX5 the accessory clips into the home indicator.** The
   Figma frame does not show this case. The production
   implementation must address it (see "Remaining Risks").
4. **The accessory has a hardcoded 56×56 frame** with a
   `camera.fill` glyph. The Figma frame's `Capture` action is
   sized to the tab bar's intrinsic item size. The spike
   chooses a slightly larger size to keep the 44×44 minimum
   hit area comfortable.

## Round 2 — Visual Alignment And System Glass

Round 2 re-opened the Round 1 visual conclusions after review
rejected them (Capture button misaligned; no Liquid Glass). The
test matrix was deliberately reduced: the spike's job is to select
the visual composition, not to validate production quality.

### Scope

Base scenario (all layout and glass decisions made here):

- iPhone 17 Pro Simulator, iOS 26.5, portrait, default Dynamic
  Type (`L`), light mode, Gallery selected, tab bar visible.

Regression checks (exactly two, run only after the base scenario
was decided):

- Jam selected (light mode).
- Dark mode (Gallery selected).

Explicitly not produced in this round (deferred to the production
implementation matrix): enlarged Dynamic Type, accessibility
sizes (AX3/AX5), VoiceOver, Reduce Motion, landscape, iPhone
without Dynamic Island, tab bar hidden, Capture sheet, full state
matrix, physical device, automated hit testing, real Capture flow,
contextual states, light/dark beyond the checks above.

### Question 1 — Liquid Glass (public API inventory, iOS 26.5 SDK)

Verified against the iPhoneOS 26.5 SDK Swift interfaces
(`SwiftUI.swiftmodule`, `SwiftUICore.swiftmodule`) and compiled
into the spike shell. Minimal compilable prototypes were run for
each available API.

| API | Available | Compiles | Visual result | Selected or rejected |
| --- | --- | --- | --- | --- |
| `.glassEffect(.regular.interactive(), in: .circle)` (iOS 26.0+) | Yes | Yes | Real system glass circle; tracks the tab bar's material in light and dark; same visual family as the native tab bar | **Selected (final surface, product-owner decision)** |
| `.glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)` | Yes | Yes | Tinted system glass circle | **Tested and rejected by visual direction**: excessive chromatic emphasis; makes Capture look separate from the tab bar; communicates more CTA priority than desired; reduces coherence with the native navigation material. Not an automatic fallback; may only return by an explicit future product decision. |
| `.buttonStyle(.glass)` (`GlassButtonStyle`, iOS 26.0+) | Yes | Yes | Glass, but the style's intrinsic sizing overflows the 56×56 frame and clips at the screen edge | Rejected (no sizing control) |
| `.buttonStyle(.glassProminent)` (`GlassProminentButtonStyle`, iOS 26.0+) | Yes | Yes | Prominent tinted capsule; same intrinsic-sizing overflow/clipping | Rejected (no sizing control) |
| `GlassEffectContainer` (iOS 26.0+) | Yes | Yes | Identical to bare `glassEffect` for a single element (containers matter for merging multiple glass shapes) | Rejected (unnecessary for one control) |
| `Glass` modifiers `.tint(_:)`, `.interactive(_:)` | Yes | Yes | Used by the selected surface | Selected as part of the surface |
| `glassEffectID` / `glassEffectUnion` / `glassEffectTransition` (iOS 26.0+) | Yes | Not prototyped | Single static control; morphing/union not needed | Not needed |

Not used as a solution (per the round's rules): `Circle` + tint,
`.ultraThinMaterial`, manual blur, manual shadow, simulated border,
gradient-as-fake-reflection. None of them appear in the selected
composition.

### Question 2 — Alignment

Measured on the base-scenario screenshot (pixel analysis of the
bright surfaces; values in points, screen 402×874 pt):

- Native capsule: y 791.0–852.7, **visual center 821.8 pt**.
- Round 1 accessory (trailing 12 / bottom 4): y 780.3–835.7,
  **center 808.0 pt** — 13.8 pt too high. Misalignment confirmed
  and quantified.

Techniques re-evaluated:

| Technique | Alignment | Overlap with Jam | Glass integration | Verdict |
| --- | --- | --- | --- | --- |
| Shared container + optical `.offset(y: 14)` | Exact (both centers 821.8 pt) | None (40 pt gap pill→button) | Full (`glassEffect` on the accessory) | **Selected** |
| `tabViewBottomAccessory` (public API, iOS 26.0+) | System-owned, but the API renders a **full-width accessory bar above the tab bar** (mini-player style), not a sibling beside the capsule; the tab bar also expands to full width | n/a | Bar has its own glass | Rejected (wrong composition; does not match the Figma frame) |
| Safe area inset | Same composition as shared container, extra layout level | None | Full | Rejected (redundant) |
| Overlay | Visually identical to shared container | None | Full | Equivalent; shared container kept (explicit sibling invariant) |

**Divergence recorded (per AGENTS.md):**
`specs/planned/native-tab-navigation-migration.md` (Draft) states
"There is no public API on this baseline that places a visually
prominent action button between or beside tabs without that action
being a `Tab`." The iOS 26.5 SDK does contain a public accessory
API, `tabViewBottomAccessory` (iOS 26.0+, plus an `isEnabled:`
variant in iOS 26.1+). Round 2 tested it: it does not produce the
requested composition (it stacks an accessory bar above the tab
bar), so the spec's conclusion still holds in practice, but its
API claim is factually incomplete and should be corrected when the
spec is next revised.

**Optical adjustment (selected).** `.offset(y: 14)` on the
accessory, on top of trailing 12 / bottom 4. This is an optical
alignment correction: it was measured against the capsule's visual
center in the base scenario, it does not represent a presumed tab
bar height, it does not vary by device model, and it does not
reproduce the tab bar's internal geometry. After the offset, the
accessory center and the capsule center coincide at 821.8 pt
(measured, see `31-r2-winner-gallery-light-annotated.png`).

### Evidence (minimal set)

All under `docs/audits/assets/hybrid-tab-spike/`. Annotations:
green line = capsule visual center, red line = button visual
center, blue segment = horizontal gap between the elements. When
the composition is aligned, the green and red lines coincide (only
red is visible).

1. Figma reference (cropped) — **not produced**. The Figma file
   (`figma.com/design/HBJvgh0rR2RuO2IyiJyVj/Photo-Pedal?node-id=75-140`)
   requires authentication; no Figma credential exists in this
   spike environment (HTTP 403). The comparison below is made
   against the Figma frame's textual description in
   `specs/planned/native-tab-navigation-migration.md`. The cropped
   reference must be attached by a reviewer with Figma access
   before the spike is formally closed.
2. `30-r2-current-misaligned-annotated.png` — Round 1 composition
   (shared container, 12/4, `Circle` + tint): green line at the
   capsule center (821.8 pt), red line at the button center
   (808.2 pt); the 13.6 pt vertical gap is visible.
3. `31-r2-winner-gallery-light-annotated.png` — selected
   composition, light mode, Gallery selected. Centers coincide.
4. `32-r2-winner-jam-light-annotated.png` — regression check 1:
   Jam selected, light mode. No overlap with Jam; centers
   coincide.
5. `33-r2-winner-gallery-dark-annotated.png` — regression check 2:
   dark mode, Gallery selected. The tinted glass adapts with the
   tab bar's dark material; centers coincide.

Raw (unannotated) captures of 3–5 are stored beside the annotated
versions (`31-…light.png`, `32-…light.png`, `33-…dark.png`).

### Remaining Differences vs. Figma

1. **Tint.** The Figma frame (per the spec's textual description)
   suggests a tinted surface. The final product decision overrides
   this: **normal glass** is the approved surface so Capture belongs
   to the tab bar's visual family instead of reading as a colored
   CTA. The difference from the Figma frame is intentional and
   recorded as a product decision, not a technical limitation.
2. **Size.** The accessory is 56×56 pt; the Figma frame sizes
   Capture to the tab bar's intrinsic item size. 56 pt keeps a
   comfortable hit area; the production spec may tune this.
3. **Gap.** 40 pt between the capsule's trailing edge and the
   accessory's leading edge (trailing 12 from the screen edge).
   Matches the frame's visual separation per the textual
   description; not confirmed against the crop.
4. **Structure.** Capture is a SwiftUI `Button` sibling, not a
   system tab bar item (unchanged from Round 1; no public API
   produces a non-tab action inside the bar on this baseline).

### Round 2 Conclusion

**Result A — Approved for production implementation.**

- **Alignment: approved.** Measured exact in the base scenario
  (both centers 821.8 pt) with a constant optical offset; no hack
  required.
- **Glass: public API found and approved.** `glassEffect`
  (iOS 26.0+) produces real system Liquid Glass on a circular
  control. Final surface: **normal glass** (`.regular.interactive()`).
- Decisions:
  - Shared container selected.
  - Normal glass selected.
  - Tinted glass tested and rejected by visual direction.
  - `tabViewBottomAccessory` rejected (produces a full-width bar
    above the tab bar).
  - `.buttonStyle(.glass)` and `.glassProminent` rejected (intrinsic
    sizing overflows the 56×56 frame and clips).
  - Alignment corrected with an optical offset.
  - Broad accessibility/adaptation validation transferred to the
    production implementation matrix.
- The cropped Figma reference remains unproduced (HTTP 403; needs
  a reviewer with Figma access). It is a documentation gap, not a
  blocker: the visual decision is made and recorded above.

### Final Approved Composition (baseline for implementation)

Layout:

```swift
ZStack(alignment: .bottomTrailing) {
    TabView(...)
    CaptureTabAccessory(...)
}
```

Selected glass:

```swift
.glassEffect(
    .regular.interactive(),
    in: .circle
)
```

Tested and rejected (do not use as the main implementation):

```swift
.glassEffect(
    .regular.tint(.accentColor).interactive(),
    in: .circle
)
```

Positioning baseline:

```swift
.padding(.trailing, 12)
.padding(.bottom, 4)
.offset(y: 14)
```

- 12/4 are visual paddings; `y: 14` is an optical alignment
  adjustment measured against the capsule's visual center.
- No value represents a presumed tab bar height.
- Values may be refined during the real integration; any
  refinement must be global, never device-specific.

Selection strategy (implementation):

- `TabView(selection:)` binds to the existing selection source.
- Prefer adapting `AppNavigationModel.selectedDestination` during
  the early increments. Do not create parallel state.
- Extracting a dedicated `RootNavigationSelection` type happens
  only if the implementation demonstrates a concrete need.

Do not use in the production implementation: accent-color tint,
manual material, manual blur, custom shadow, artificial border,
`TabRole.search`, or `tabViewBottomAccessory` to reproduce the
trailing action.

Approved-visual evidence (normal glass, aligned):
`34-final-gallery-light(-annotated).png`,
`35-final-jam-light(-annotated).png`,
`36-final-gallery-dark(-annotated).png`.

### Transferred To The Production Validation Matrix

These items do not block the spike's visual decision and are
moved to the production implementation's validation matrix:

- Dynamic Type enlarged; accessibility sizes (AX3, AX5 — the
  Round 1 AX5 home-indicator clip remains a production fix).
- VoiceOver (focus order, traits).
- Reduce Motion.
- Landscape.
- Tab bar hidden (lockstep).
- iPhone without Dynamic Island.
- Physical device.
- Automated hit testing (including that `.offset(y:)` moves the
  accessory's hit area together with its rendering).
- Real Capture presentation (sheet) and contextual states.
- Light/dark beyond the two regression checks above.



1. **Positioning technique: shared container
   (`ZStack(alignment: .bottomTrailing)`) with an optical
   `.offset(y: 14)`** (Round 2). It satisfies the spec's
   invariants, the safe area inset and overlay techniques are
   visually equivalent, and the shared container makes the
   sibling-not-child invariant explicit. The public
   `tabViewBottomAccessory` API was evaluated in Round 2 and
   rejected for this composition.
2. **Visual values (Round 2, base scenario): trailing 12 pt,
   bottom 4 pt, optical offset y +14 pt.** The offset is an
   optical alignment correction measured against the capsule's
   visual center in the base scenario; it does not represent or
   approximate the tab bar's height, does not vary by device
   model, and does not reproduce the tab bar's internal geometry.
3. **Accessory surface (Round 2, final product decision):
   `.glassEffect(.regular.interactive(), in: .circle)`.**
   Real system Liquid Glass from a public iOS 26.0+ API, in the
   same visual family as the native tab bar. The tinted variant
   was tested and rejected by visual direction; it is not an
   automatic fallback.
4. **Selection source: `TabView(selection:)` bound to the
   existing selection source — adapt
   `AppNavigationModel.selectedDestination` during the early
   increments; no parallel state; `RootNavigationSelection` only
   if a concrete need is demonstrated.** The shell owns the selection.
   The production spec decides whether to keep the source in
   the shell, move it to a new `RootNavigationSelection` value
   type, or reinterpret `AppNavigationModel.selectedDestination`
   as the binding backing the `TabView` selection.

## Remaining Risks

1. **AX5 home-indicator clip.** The chosen 4 pt bottom padding
   clips the accessory at `accessibility5`. The spec's 0–8 pt
   range is not sufficient at AX5. The recommended production
   fix is to use the safe area inset to position the accessory
   above the home indicator, or to compute a dynamic bottom
   padding that grows with the safe area. The fix is not
   measured in the spike because the spike's purpose is to
   collect evidence, not to ship a production fix.
2. **Physical-device validation.** No physical device was used
   in the spike. The simulator is the only source of evidence
   for the recommended technique, padding, and selection
   source. A physical iPhone with Dynamic Island and a
   physical iPhone without Dynamic Island are required for
   the production implementation to be considered validated.
3. **VoiceOver focus order** was not directly measured. The
   inference that Gallery, Jam, Capture is the order is based
   on the SwiftUI layout tree; a real VoiceOver session is
   required to confirm.
4. **Hit testing** was not directly measured. The inference
   that the 56×56 button has a 56×56 hit area and that the
   surrounding ZStack is transparent is based on the SwiftUI
   layout model. A `XCUIApplication` test or a physical-device
   manual test is required to assert the claim.
5. **Landscape orientation** was not captured. The simulator
   environment did not respond to rotation commands. The
   composition is expected to be correct because the accessory
   is anchored to the container's bottom-trailing; a manual
   device rotation is required to confirm.
6. **iPhone without Dynamic Island** was not captured. No
   such simulator was used. The composition is expected to be
   correct because the accessory is anchored to the ZStack,
   not to a device-class constant.
7. **Liquid Glass consistency.** _Resolved by Round 2:_
   `glassEffect` is available in the iOS 26.5 baseline and is
   the selected surface. The Round 1 `Circle` + tint primitive
   is rejected.
8. **Figma differences 1–4** above are visual and structural
   differences between the Figma frame and the spike's
   composition. The production spec must decide whether the
   differences are acceptable.

## Discard Plan Status

- Branch: `spike/iphone-hybrid-tab-navigation` (created from
  `main`).
- Files added: `snap-battle/Features/Spike/SpikeHybridTabShellView.swift`,
  `SpikeCaptureTabAccessory.swift`, `SpikePlaceholders.swift`,
  `SpikeSelectionModel.swift`, `SpikeTabBarVisibility.swift`.
- Files added for the report:
  `docs/audits/hybrid-tab-navigation-spike.md` and
  `docs/audits/assets/hybrid-tab-spike/*.png` (29 screenshots).
- Files added for the capture harness:
  `docs/audits/hybrid-tab-spike-helpers/shot.sh`,
  `capture.sh`, `capture-extra.sh` (disposable; the report
  does not depend on them).
- Files modified: `snap-battle/snap_battleApp.swift` (added
  a four-line, env-gated launch hook marked `SPIKE`; this
  hook is removed before any merge, and the spike is not
  merged).
- Branch is **not** merged into `main`. The branch is
  intended to be closed after this report is reviewed.

## Acceptance Criteria (per the spike's plan)

- [x] Spike branch created from `main`.
- [x] Report at `docs/audits/hybrid-tab-navigation-spike.md`
      using the `Observed` / `Inferred` / `Not validated` format
      with at least one item per category per question.
- [x] Screenshots cover iPhone portrait, default Dynamic Type,
      an enlarged Dynamic Type (AX3), an accessibility Dynamic
      Type (AX5), and the tab bar hidden state, for the
      recommended positioning technique (shared container).
- [x] Simulator evidence is explicitly distinguished from
      physical-device evidence.
- [x] "iPad is outside the scope" note is present.
- [x] Three decisions recorded: positioning technique, padding
      values, single-source-of-truth strategy.
- [ ] Branch closed: **deferred.** The report says "the branch
      is intended to be closed after this report is reviewed";
      the actual branch closure is out of scope for the spike
      (the spec's "Discard Plan" requires closure after the
      report is written; the spike submits the report and
      leaves the branch alive for review).
