# ADR 0005: Image Processing Concurrency Boundary

Status: Accepted
Date: 2026-07-16

## Context

`PhotoPedalViewModel` is `@MainActor` at
`snap-battle/Features/Capture/CaptureViewModel.swift:4`, and the `Task` created
by `process(_:)` at line 43 inherits that actor. `PhotoPedalPipeline` is also
`@MainActor` at `snap-battle/Services/Pedal/PhotoPedalPipeline.swift:3`.
Consequently, the synchronous preparation at lines 57–59, color analysis at
lines 65–67, and sequence generation at lines 68–70 currently start from the
main executor. The audit records a warmed median of 196.3 ms and a maximum of
394.5 ms for `imagePreparation`; those measurements do not establish a
SwiftUI-rendering bottleneck or a relationship with legacy Snap Battle code.

The current `PreparedImage` at
`snap-battle/Services/ImageInputPreparer.swift:5-10` stores a `UIImage` and is
declared `@unchecked Sendable`. `UIImage` also remains the input and output
type of `RetroImageProcessor` (`snap-battle/Services/ImageProcessing/RetroImageProcessor.swift:4-6`),
`PhotoColorAnalyzer` (`snap-battle/Services/Pedal/PhotoColorAnalyzer.swift:12-14`),
and `ImageSequenceGenerator` (`snap-battle/Services/Pedal/ImageSequenceGenerator.swift:4-6`).
Vision consumes a `CGImage` at
`snap-battle/Services/Vision/VisionObjectAnalyzer.swift:6-10`, while
`SubjectExtractionService` is intentionally MainActor-isolated at
`snap-battle/Services/Vision/SubjectExtractionService.swift:21-40`.

The effective project settings are the same in Debug and Release unless noted:

| Concern | Effective value | Definition |
| --- | --- | --- |
| Compiler | Xcode 26.5, build 17F42; the project invokes that toolchain | `xcodebuild -version`; toolchain, not `SWIFT_VERSION` |
| Swift language mode | Swift 5 | app Debug/Release `project.pbxproj:368-372, 405-409`; tests `:430-432, 454-456` |
| Default actor isolation | `MainActor` | app `:368-369, 405-406`; tests `:430-431, 455` |
| Approachable concurrency | `YES` for app Debug/Release and test Debug | app `:368`; test `:430`; absent from test Release |
| Strict concurrency | Not explicitly set | no `SWIFT_STRICT_CONCURRENCY` setting in the project/target settings |
| Deployment target | iOS 26.5 | project `:272, 330`; tests `:421, 445` |
| SDK | `iphoneos26.5.sdk` for the inspected scheme configuration | `xcodebuild -showBuildSettings` |
| Optimization | `-Onone` in Debug; Release uses whole-module compilation and inherits the Release optimization defaults | project `:279, 335` |

`SWIFT_VERSION = 5.0` therefore describes language mode, not compiler version,
SDK version, deployment target, or strict-concurrency level. This ADR does not
change any of those settings. The boundary must be valid in the current mode;
future Swift 6 language-mode migration is a separate decision.

## Decision

Use a project-owned, immutable pixel value as the only representation that
crosses the image-preparation concurrency boundary:

```swift
struct ImagePixelBuffer: Sendable {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let format: PixelFormat       // RGBA8, sRGB, premultiplied-last
    let data: Data
}
```

The concrete contract is:

- `width` and `height` are the normalized pixel dimensions;
- `bytesPerRow == width * 4` for the canonical packed representation;
- `data` contains exactly `bytesPerRow * height` bytes in row order;
- the color space is sRGB, components are 8-bit, alpha is premultiplied-last;
- orientation is always `.up` and is represented by the row order, not by a
  UIKit orientation flag;
- `Data` owns the bytes, and no mutable buffer, `UIImage`, `CGImage`, Core Image
  object, or UIKit object is stored in the value.

The UIKit adapter owns the input conversion. On the MainActor, the capture
boundary obtains the source `CGImage` and orientation from the incoming
`UIImage`, then copies the source pixels into an `ImagePixelBuffer` before
dispatch. `ImageInputPreparer` owns orientation normalization and fingerprint
rendering, but its concurrent API accepts and returns only pixel values and
value metadata. The normalization render uses the existing image orientation,
sRGB color space, interpolation, alpha, and dimensions; it must not introduce
downsampling, a new format, or a new resolution.

The preparation executor is a dedicated serial `ImagePreparationExecutor`
implemented as an actor (or an equivalent serial `Sendable` service if actor
isolation is sufficient). It performs normalization, canonical pixel copying,
and the existing 32×32 fingerprint calculation. It does not run cover, color,
sequence, Vision, metadata, or persistence stages concurrently. A caller may
cancel before dispatch and the executor must check cancellation before and
after the synchronous preparation work.

The result crossing back is an immutable `PreparedImageValue` containing the
canonical normalized `ImagePixelBuffer`, `originalSize`, `processedSize`, and
`fingerprint`. The MainActor adapter materializes the existing `UIImage` only
when handing the value to the unchanged UIKit-facing collaborators. That
materialization is explicitly outside the concurrent value boundary. The
existing `PreparedImage` must not remain `@unchecked Sendable` for this path;
the implementation either replaces it with the value type plus a MainActor
UIKit adapter or keeps a UIKit-only wrapper that never crosses `await`.

The MainActor owns `PhotoPedalViewModel` state updates (`stage`,
`isProcessing`, `pendingPedal`, `pendingCover`, errors, and presentation). The
pipeline remains sequential: preparation, cover, color, sequence, metadata,
persistence, and result. Results are discarded when cancellation is observed;
no cancelled task may persist or present a later result. `RetroImageProcessor`
remains unchanged even though its current implementation already uses a
detached task at `RetroImageProcessor.swift:46-50`.

### Compatibility contract

`RetroImageProcessor`, `PhotoColorAnalyzer`, and `ImageSequenceGenerator` keep
their current `UIImage` APIs for this implementation slice. Their adapters
receive a MainActor-created `.up` image materialized from the canonical buffer,
so they see the same dimensions, pixels, sRGB semantics, and orientation as
today. `VisionObjectAnalyzer` continues to convert the prepared image to
`CGImage` at `VisionObjectAnalyzer.swift:8`; `SubjectExtractionService` remains
UIKit/VisionKit-specific and MainActor-isolated. No Vision or Foundation Models
operation is moved by this ADR. `FoundationModelsPedalGenerator` remains
outside deterministic music generation.

### Equivalence and diagnostics

The implementation must prove equality for the same fixture at normalized
dimensions, canonical pixel bytes, fingerprint, cover pixels/dimensions,
`PhotoColorProfile`, `PedalHarmony`, ordered notes, and `PedalSoundProfile`.
UUID, dates, and semantic metadata remain excluded. `PerformanceDiagnostics`
continues to use the existing run ID and must report the preparation executor
without image content; its DEBUG-only behavior at
`snap-battle/Supporting/PerformanceDiagnostics.swift:8-33` remains unchanged.

No `@unchecked Sendable` is added. Any remaining occurrence must be confined
to unrelated legacy code until a separate approved cleanup; it cannot be used
to justify crossing this boundary.

## Alternatives Considered

| Option | Concurrency safety | Compatibility | Cost / risk | Decision |
| --- | --- | --- | --- | --- |
| A. `UIImage` across the boundary | Requires unsafe suppression under the current model; mutable UIKit ownership is unclear | Highest immediate source compatibility | Lowest code churn, highest race and lifetime risk; rejected by the existing `PreparedImage` evidence | Reject |
| B. `CGImage` across the boundary | Better ownership semantics, but compiler/SDK Sendability annotations are not a project-owned guarantee in the current Swift 5 mode | Good for Vision/ImageIO and Core Graphics; UIKit consumers still need adapters | Low conversion cost, but acceptance depends on SDK annotations and can regress with toolchain changes | Reject as the canonical contract |
| C. Encoded `Data` (PNG/JPEG/HEIF) | Sendable and owned | Requires decode for every Core Graphics/UIKit consumer | Encode/decode overhead, possible color/alpha/orientation changes, and format-dependent pixel drift | Reject |
| D. Owned RGBA pixel buffer | Fully value-based and compiler-accepted through Foundation `Data`; no unsafe conformance | Requires one adapter to existing UIKit APIs; directly supports Core Graphics, Vision, and ImageIO materialization | Moderate localized change and one owned copy; preserves exact pixels when the explicit format contract is honored | Accept |
| E. `CIImage` across the boundary | Not a concrete owned pixel snapshot; evaluation is lazy and thread/lifetime semantics become part of the contract | Adds Core Image concepts to a UIKit/Core Graphics pipeline | More conceptual complexity and risk of evaluation differences | Reject |

Option D also leaves a reversible path for future downsampling: a later
specification may add a distinct canonical buffer contract and equivalence
version. This ADR does not authorize downsampling or algorithm changes.

## Consequences

### Positive

- The concurrent boundary has explicit ownership, format, dimensions, and
  orientation, without `@unchecked Sendable`.
- The deterministic image-to-music contract can compare stable bytes before
  reaching existing UIKit-facing services.
- Existing Vision, RetroImageProcessor, PhotoColorAnalyzer, and
  ImageSequenceGenerator behavior remains reusable through localized adapters.
- Cancellation and sequential pipeline ordering have a precise executor seam.
- The project can remain in Swift 5 language mode while using the Xcode 26.5
  compiler and iOS 26.5 SDK.

### Negative

- A full-resolution owned byte copy increases peak memory during the handoff;
  the implementation must release redundant source values as soon as the
  adapter permits.
- UIKit materialization remains a synchronous adapter operation and must be
  measured separately from preparation; this ADR does not claim that every
  image-related millisecond leaves MainActor.
- Existing `UIImage` APIs and legacy `CreaturePipeline` references to
  `PreparedImage` require careful compatibility edits in the implementation.
- Pixel equivalence still needs focused tests and physical-device validation;
  this ADR establishes the contract but does not perform those changes.

## References

- [Image preparation executor boundary](../../specs/current/image-preparation-executor-boundary.md)
- [Architecture](../ARCHITECTURE.md)
- [Image-to-music generation](../IMAGE_TO_MUSIC.md)
- [Testing](../TESTING.md)
- [Photo Pedal import and legacy audit](../audits/photo-pedal-import-and-legacy-audit.md)
- [ADR 0001: Deterministic local music generation](0001-deterministic-local-music-generation.md)
- [ADR 0002: Persist generated musical results](0002-persist-generated-musical-results.md)
- [ADR 0003: Foundation Models for semantic metadata](0003-foundation-models-for-semantic-metadata.md)
