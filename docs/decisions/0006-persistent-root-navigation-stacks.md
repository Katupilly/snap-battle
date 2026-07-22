# ADR 0006: Persistent Root Navigation Stacks

Status: Accepted
Date: 2026-07-22

## Context

Gallery's native thumbnail-to-Inspector zoom was originally implemented with `matchedTransitionSource` and `navigationTransition(.zoom)`. Later attempts to coordinate root chrome replaced it with a manual overlay and matched geometry, producing global fades, duplicated artwork, unstable return frames, and chrome captured in the transition lifecycle. The Hero is suspended for the current delivery and deferred to a future isolated spike.

Gallery and Jam need independent navigation history, while Capture and the custom root navigation must remain global shell concerns. Persisted pedals already have stable UUID identity, so routes do not need to carry domain objects.

## Decision

- Keep Gallery and Jam as persistent sibling roots. Each owns one `NavigationStack` and a separately typed path.
- Use `GalleryRoute.inspector(UUID)` for Photo Inspector. Jam routes never contain Gallery destinations.
- Keep both roots mounted while switching opacity, interaction, accessibility, and z-order without a root transition animation.
- Keep Photo Inspector as `GalleryRoute.inspector(UUID)` inside the persistent Gallery stack. Use the default native `NavigationStack` transition for this delivery.
- Keep root chrome and transient Capture mounted outside both navigation stacks. Derive chrome visibility from the selected root, the active root path, and Capture presentation.
- Preserve root paths when switching destinations. Capture cancellation restores the prior root; Capture completion follows the existing product contract and selects Gallery.
- App Intents and external routes select the owning root before mutating only that root's path.
- Do not replace the deferred Hero with an overlay, manual matched geometry, custom gesture, global fade, delay, or snapshot transition.

## Consequences

### Positive

- Root chrome, Jam, and shell safe-area adjustments stay outside Gallery's native stack transition lifecycle.
- Interactive pop remains native and supports cancellation without a custom edge gesture.
- Gallery and Jam preserve navigation, view-model, and scroll identity across root switches.
- Routes remain small, typed, and based on persisted identity.

### Negative

- Both root stacks remain mounted, increasing the retained SwiftUI view tree.
- Shell visibility derivation must account for two independently typed paths.
- Existing tests and documentation using global `AppRoute` require migration.

## Alternatives Considered

- One shell-owned route type for both roots: rejected because it permits cross-root destinations and couples Gallery lifecycle to shell navigation.
- Manual Inspector overlay with `matchedGeometryEffect`: rejected by visual evidence and interactive-pop regressions.
- Nested Gallery stack inside a global stack: rejected because it retains competing navigation owners and gesture/chrome ambiguity.

## References

- [Navigation and Gallery Foundation](../../specs/current/navigation-gallery-foundation.md)
- [Dap Library](../../specs/current/pedal-library.md)
- [Hybrid Tab Navigation](../../specs/current/hybrid-tab-navigation-implementation.md)
- [Architecture](../ARCHITECTURE.md)
- Gallery Hero references, deferred for future spike: `53adaf2d`, `19cb9224`, `4eda4959`
