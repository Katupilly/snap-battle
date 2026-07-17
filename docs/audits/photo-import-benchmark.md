# Photo Import Benchmark PoC

Date: 2026-07-17
Status: Completed investigation; no production migration

## Objective

Compare the current library import path with two isolated PhotoKit strategies to determine whether `PhotosPickerItem.loadTransferable(type: Data.self)` is the main source of observed import latency and whether `PHImageManager` `.fastFormat` can safely serve as the canonical image for a Photo Pedal run.

This audit does not authorize migration to `PHImageManager`, roadmap changes, ADRs, or production-flow changes.

## Methodology Audit Result

The original benchmark was asymmetric for pipeline-ready comparison:

- Variant A acquired full transferred `Data`, decoded the original-sized image, and sent that image onward.
- Variants B and C acquired a `PHImageManager` image with `targetSize: 1024x1024`.
- The original total time did not explicitly separate acquisition from orientation correction and resize/downsampling to the shared `1024x1024` limit.
- The original PhotoKit callback handling accepted the first image callback, which could confuse a degraded callback with the final artifact.

The benchmark now keeps two comparisons separate:

- `acquisitionDuration`: time until the API delivers its initial usable representation.
- `pipelineReadyDuration`: time until the benchmark has a semantically comparable image artifact for the downstream pipeline: oriented `.up`, limited to max `1024x1024`, and not a degraded PhotoKit delivery.
- `endToEndDuration`: time measured directly from request start to the pipeline-ready artifact, without deriving it from component sums.

The follow-up physical-device audit found no code path that discards a non-nil `PhotosPickerItem.itemIdentifier` before B/C execution. The `PhotosPickerItem` selected by the user is stored directly in `PhotoImportBenchmarkView.selectedItem`, captured into a local `item`, and passed unchanged into `PhotoImportBenchmarkRunner.run`. The runner reads `item?.itemIdentifier` before calling `loadTransferable(Data.self)` or creating any `UIImage`. If it is nil, B/C correctly record `missingItemIdentifier`. No filename, date, dimension, hash, or content correlation is used.

## Architecture

The completed PoC is DEBUG-only, experimental, and removable:

- `Features/Debug/PhotoImportBenchmark/PhotoImportBenchmarkView.swift` provides the benchmark UI, including single-strategy runs and rotating full-round runs.
- `Services/Debug/PhotoImportBenchmark/PhotoImportBenchmarkRunner.swift` executes the three strategies, collects timings, creates the pipeline-ready image, and calls the current `PhotoPedalPipeline.runEssential` path.
- `Services/Debug/PhotoImportBenchmark/PhotoImportBenchmarkModels.swift` contains benchmark metrics, output-comparison logic, and rotating-order logic.
- `ContentView` has a small `#if DEBUG` launcher sheet only. The production capture/import handler is unchanged.

The benchmark does not write pedals to persistence, does not update Gallery, does not invoke App Intents, and does not run semantic metadata enrichment. It may be kept temporarily as a diagnostic tool, but it is not a product feature or production import strategy.

The UI now separates two DEBUG-only surfaces:

- `PhotosPicker benchmark`: Variant A uses `PhotosPickerItem.loadTransferable(Data.self)`. B/C may attempt the original `PhotosPickerItem -> itemIdentifier -> PHAsset` path, but fail as `missingItemIdentifier` when the picker item has no identifier.
- `PhotoKit asset benchmark`: B/C receive a `PHAsset` selected directly through an experimental PhotoKit asset picker. This is not the same selection or authorization flow as Variant A and must not be presented as a definitive architectural comparison.

## Variants

| Variant | Acquisition API | Acquisition representation | Pipeline-ready rule |
| --- | --- | --- | --- |
| A | `PhotosPickerItem.loadTransferable(type: Data.self)` | Transferred `Data`, then `UIImage(data:)` | Decode, correct orientation to `.up`, resize only if max dimension exceeds `1024`, then send that image to the essential pipeline. |
| B | `PHImageManager.requestImage` with `.fastFormat`, `targetSize: 1024x1024` | Non-degraded `UIImage` returned by PhotoKit | Ignore degraded callbacks, correct orientation to `.up`, resize only if max dimension exceeds `1024`, then send that image to the essential pipeline. Latest physical data shows this may still be a very small thumbnail and not a comparable pipeline-ready artifact. |
| C | `PHImageManager.requestImage` with `.highQualityFormat`, `targetSize: 1024x1024` | Non-degraded `UIImage` returned by PhotoKit | Same as B. |

Both PhotoKit variants use `contentMode: .aspectFit`, `resizeMode: .fast`, `version: .current`, asynchronous delivery, the same fixed target size, and configurable network access. The benchmark does not use `.opportunistic` delivery mode.

Exact `PHImageRequestOptions` configuration in the current runner:

- `deliveryMode`: `.fastFormat` for B, `.highQualityFormat` for C;
- `resizeMode`: `.fast`;
- `contentMode`: `.aspectFit` in the `requestImage` call;
- `targetSize`: `CGSize(width: 1024, height: 1024)`, passed as the PhotoKit target size and treated as the pixel target for this benchmark, with no device-scale upscaling applied by the app;
- `isNetworkAccessAllowed`: controlled by the benchmark toggle;
- `version`: `.current`;
- `isSynchronous`: `false`;
- `progressHandler`: installed to count iCloud/network progress callbacks and approximate cloud wait.

For the `PhotoKit asset benchmark`, the selected `PHAsset.localIdentifier`, pixel dimensions, authorization state, and selection availability are emitted only to DEBUG logs at run time. The local identifier is not displayed, persisted, or integrated into production Capture.

## Metric Boundaries

| Metric | Starts | Ends | Applies to |
| --- | --- | --- | --- |
| `assetResolutionDuration` | Immediately before `PHAsset.fetchAssets(withLocalIdentifiers:)` | After `fetch.firstObject` resolves or fails | B/C only |
| `cloudWaitDuration` | First PhotoKit progress callback for an iCloud-backed request | Non-degraded PhotoKit image callback | B/C when PhotoKit reports progress |
| `acquisitionDuration` | Immediately before `loadTransferable` or `requestImage` | A: `Data?` returned by `loadTransferable`; B/C: first non-degraded `UIImage` returned by `PHImageManager` | A/B/C |
| `decodeDuration` | A: before `UIImage(data:)`; B/C: before validating the returned `UIImage.cgImage` | A: decoded `UIImage` and `CGImage` exist; B/C: returned image has a `CGImage` | A/B/C |
| `orientationDuration` | Before orientation normalization | A `.up` `UIImage` exists | A/B/C |
| `resizeDuration` | Before applying the `1024` max-dimension limit | Image is unchanged if already within limit, otherwise resized with aspect ratio preserved | A/B/C |
| `pipelineReadyDuration` | A: immediately before transforming `Data` into `UIImage`; B/C: immediately after receiving the final non-degraded `UIImage` | After producing a `.up` `UIImage` limited to max `1024x1024` without upscaling | A/B/C |
| `endToEndDuration` | Immediately before `loadTransferable` or `requestImage` | After producing the pipeline-ready artifact | A/B/C |
| `essentialPipelineDuration` | Before `PhotoPedalPipeline.runEssential` | Essential result returns or throws | A/B/C |
| `totalDuration` | Before per-strategy setup | After success, cancellation, or error result is produced | A/B/C |

`requestMilliseconds` remains displayed as a compatibility alias for acquisition in existing UI/log contexts, but methodological comparisons should use `acquisitionDuration`, `pipelineReadyDuration`, and `endToEndDuration`.

## Final Artifact

The final artifact for benchmark comparison is a `UIImage` ready for the existing essential pipeline with these properties:

- orientation normalized to `.up`;
- max width and max height bounded by `1024` without upscaling smaller images;
- aspect ratio preserved;
- non-degraded for PhotoKit variants;
- dimensions recorded as `pipelineReadySize`;
- representation type recorded as `Data -> UIImage` for A or `PHImageManager UIImage` for B/C;
- approximate byte size recorded as transferred `Data.count` for A or `cgImage.bytesPerRow * height` for B/C.

The benchmark also records source dimensions, API-delivered dimensions, degraded/final flags, and degraded delivery count.

## Target Size

Selected target size: `1024x1024`.

Rationale from current implementation:

- cover generation outputs 160 px wide;
- color analysis samples 64x64;
- fingerprint samples 32x32;
- musical grid samples 16x8 from the cover;
- Vision currently consumes the prepared image, but the PoC runs only the essential path and does not benchmark semantic enrichment.

`1024x1024` is intentionally above the deterministic cover/music requirements while bounding high-resolution originals. It is shared by B/C at PhotoKit request time and by A/B/C at the pipeline-ready boundary.

## Known Confounders

- Photos, PhotoKit, image decoding, and iCloud can use system caches that are not controlled by the app.
- Running A/B/C in a fixed order can bias warm-cache results toward later variants.
- `.fastFormat` may return smaller or lower-quality images than requested. Latest physical data showed thumbnails of only 68-120 px on the largest axis despite the `1024x1024` target, so `.fastFormat` timings must not be compared directly with A or C as equivalent-quality acquisition timings.
- PhotoKit can produce degraded callbacks before a final callback. The benchmark ignores degraded callbacks for the pipeline-ready artifact and records `degradedDeliveryCount`.
- iCloud status is not inferred from duration. It is identified only when PhotoKit provides progress or an in-cloud/no-image failure with network disabled.
- `PhotosPickerItem.itemIdentifier` may be `nil`; this makes B/C non-executable for that selected item while A remains executable.
- Physical testing reproduced `itemIdentifier == nil` for every PhotosPicker selection despite PhotoKit authorization being `authorized`. In that state, the factual blocked path is `PhotosPickerItem -> itemIdentifier -> PHAsset`.
- Limited photo-library authorization can change whether the selected asset resolves through PhotoKit.
- Simulator timings are not factual product benchmark data.
- The direct `PhotoKit asset benchmark` changes both selection mechanism and authorization surface, so it can measure B/C mechanics for a chosen `PHAsset` but cannot prove equivalence to the PhotosPicker user flow.

Do not clear caches using private APIs or mechanisms that do not represent real use.

## Cache-Bias Control

Use the rotating full-round button for repeated measurements:

| Round | Order |
| --- | --- |
| 1 | A -> B -> C |
| 2 | B -> C -> A |
| 3 | C -> A -> B |
| 4 | A -> B -> C |

Record the order for every run set. Keep cold and warm runs separate.

## Authorization Model

The benchmark UI states that PhotoKit variants require photo-library authorization. It records:

- authorization state;
- whether `PhotosPickerItem.itemIdentifier` exists;
- unresolved asset failures;
- network access enabled or disabled;
- degraded/final flags when PhotoKit supplies them;
- degraded delivery count.

Production privacy behavior is unchanged by the PoC. Any future migration must separately justify the increased permission surface and limited-library behavior.

The PhotoKit asset selector is DEBUG-only, requests no persistence, and exists only to let B/C run against a directly selected `PHAsset` after the PhotosPicker itemIdentifier route proved unavailable in physical testing.

## Physical Device Protocol

Run on an iPhone, not the simulator:

1. Install a DEBUG build on the iPhone.
2. Open the DEBUG Photo Import Benchmark screen.
3. Select exactly one photo for the scenario being measured.
4. For PhotoKit scenarios, record current authorization state and request PhotoKit authorization only when the scenario requires B/C execution.
5. Run at least one cold round after app launch using the rotating full-round button.
6. Run at least two additional warm rounds for the same selected item using the rotating full-round button.
7. For iCloud scenarios, run B/C once with network disabled and once with network enabled; record failures, progress/iCloud wait, and whether A succeeds.
8. For limited-library scenarios, ensure the selected item is inside or outside the limited set as intended; do not infer behavior without recording the authorization state and asset-resolution outcome.
9. If `itemIdentifier == nil`, record B/C as `missingItemIdentifier` and continue measuring A for that item.
10. For each run, record acquisition duration, pipeline-ready duration, end-to-end-ready duration, essential duration, total duration, source size, delivered size, pipeline-ready size, representation type, approximate bytes, degraded delivery count, error category, and visible/musical comparison.
11. Do not declare a winner from a single photo, a single warm run, or simulator data.

## Scenarios

| Scenario | Status |
| --- | --- |
| Small local photo | not run |
| Recent camera photo | not run |
| High-resolution photo | not run |
| Confirmed iCloud-backed photo | not run |
| Same photo first run | not run |
| Same photo warm run | not run |
| Limited library access | not run |
| Missing `itemIdentifier` | reproduced on physical device; B/C ended with `missingItemIdentifier` |

Each physical-device scenario should be run at least three times per strategy, with cold/warm status, rotating order, median, min, max, delivered size, pipeline-ready size, failures, and cancellations recorded.

## Results Table

| Scenario | Run | Cold/Warm | Order | Strategy | Auth | Network | Acquisition ms | Pipeline-ready ms | End-to-end ms | Essential ms | Total ms | Source | Delivered | Ready | Representation | Approx bytes | Degraded callbacks | Error | Visual | Musical |
| --- | ---: | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- | ---: | ---: | --- | --- | --- |
| Small local photo | 1 | cold | A-B-C | A | not run | n/a |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| Small local photo | 1 | cold | A-B-C | B | not run | off |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| Small local photo | 1 | cold | A-B-C | C | not run | off |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| Recent camera photo |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| High-resolution photo |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| iCloud-backed photo |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| Limited library access |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| Missing `itemIdentifier` |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |

## Summary Table

| Scenario | Strategy | Runs | Acquisition median | Acquisition min-max | Pipeline-ready median | Pipeline-ready min-max | Error rate | Delivered sizes | Ready sizes | Notes |
| --- | --- | ---: | ---: | --- | ---: | --- | ---: | --- | --- | --- |
| Small local photo | A | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| Small local photo | B | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| Small local photo | C | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| Recent camera photo | A | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| Recent camera photo | B | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| Recent camera photo | C | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| High-resolution photo | A | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| High-resolution photo | B | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| High-resolution photo | C | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| iCloud-backed photo | A | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| iCloud-backed photo | B | 0 | not run | not run | not run | not run | not run | not run | not run |  |
| iCloud-backed photo | C | 0 | not run | not run | not run | not run | not run | not run | not run |  |

## Visual Comparison

Not run. The UI displays the generated 2-bit cover, dimensions, fingerprint, and comparison to the latest successful Variant A result.

## Musical Comparison

Not run. The UI compares fingerprint, `PhotoColorProfile`, `PedalHarmony`, ordered notes, and `PedalSoundProfile`. UUID, `createdAt`, and generated metadata are excluded.

## iCloud Behavior

Not run. The PhotoKit variants expose a network-access toggle so network-disabled and network-enabled behavior can be measured separately. iCloud behavior must be recorded only from PhotoKit progress/in-cloud signals or explicit no-image failure with network disabled, not inferred from slowness.

## itemIdentifier Reliability

Physical-device testing found `PhotosPickerItem.itemIdentifier` unavailable for all selections measured, while PhotoKit authorization was `authorized`. Consequently, `photoKitFastFormat` and `photoKitHighQuality` did not execute through the PhotosPicker-derived path; both ended with `missingItemIdentifier`.

Code audit findings:

1. The benchmark `PhotosPickerItem` is created by SwiftUI `PhotosPicker(selection:matching: .images)` and stored directly in `PhotoImportBenchmarkView.selectedItem`.
2. `itemIdentifier` is read in `PhotoImportBenchmarkRunner.run` immediately after the run starts and before any strategy-specific loading.
3. The original item is preserved for the benchmark call; `Data` and `UIImage` are produced later only inside Variant A.
4. No transformation, copy, or abstraction was found that would discard an existing identifier before B/C read it.
5. The picker uses `.images`; no benchmark code indicates that the filter transforms the item after selection. No alternate presentation mode is configured in the SwiftUI `PhotosPicker`.
6. Single-strategy and rotating-round runs capture the current `selectedItem` into a local constant and pass that exact item to the runner for every strategy in that run.
7. The instrumentation records `itemIdentifierAvailable = item?.itemIdentifier != nil`; no code path was found that records `false` when a non-nil identifier exists.

When `itemIdentifier` is nil, the benchmark must treat B/C through `PhotosPickerItem -> itemIdentifier -> PHAsset` as unavailable. It must not invent an identifier or correlate assets by filename, date, dimensions, hash, or content.

## Physical Results Update

The latest physical benchmark reproduced severe tails in Variant A's `PhotosPickerItem.loadTransferable(Data.self)` acquisition path:

- fast prior Variant A acquisitions: approximately 50-199 ms;
- latest observed Variant A acquisition in this round: approximately 328 ms;
- slow prior Variant A acquisition: approximately 4,284 ms;
- extreme prior Variant A acquisition: approximately 16,774 ms;
- post-acquisition time to a normalized max-1024 px image: approximately 37-313 ms;
- the observed bottleneck is concentrated in acquisition, not the later normalization step;
- B/C did not execute through the PhotosPicker-derived path because `itemIdentifier` was unavailable and the error category was `missingItemIdentifier`.

Additional direct `PhotoKit asset benchmark` observations:

- `photoKitFastFormat` acquired images in approximately 3-7 ms, but delivered only 68-120 px on the largest axis despite `targetSize=1024x1024`.
- `.fastFormat` therefore did not produce a comparable artifact: it did not satisfy the intent of a pipeline-ready image near the 1024 px limit, and its timings should not be compared directly with A or C as equivalent-quality results.
- The runner does not upscale or otherwise transform the `.fastFormat` thumbnail into a 1024 px artifact. Smaller images remain smaller at the pipeline-ready boundary.
- `photoKitHighQuality` delivered 1024x576 or 576x1024 images and is the only observed PhotoKit candidate comparable to the intended fixed-size pipeline artifact.
- For local assets, `photoKitHighQuality` acquired in approximately 18-26 ms.
- With network access disabled, `photoKitHighQuality` failed for some assets. Current logs categorize this as PhotoKit no-result/request failure; the runner now records `PHImageErrorKey`, `PHImageCancelledKey`, `PHImageResultIsInCloudKey`, `PHImageResultIsDegradedKey`, request ID, callback count, progress callbacks, and a structured final reason so the next physical run can distinguish iCloud/no-network, cancellation, and PhotoKit error cases.
- With network access enabled, one `photoKitHighQuality` cold acquisition took approximately 2,180 ms and a warm repeat took approximately 12 ms.
- B/C still do not include the cost of arriving at a `PHAsset`. They measure only `PHImageManager` after a direct DEBUG-only PhotoKit asset selection.

These results support further measurement only. They do not identify a production winner and do not justify migration.

## Decision Rule

Do not choose a variant using only the lowest median. A future decision requires physical-device data across local and iCloud-backed assets and must consider:

- median and dispersion for both `acquisitionDuration` and `pipelineReadyDuration`;
- cold-run and warm-run behavior separately;
- local assets and confirmed iCloud assets separately;
- delivered quality and dimensions, including whether `.fastFormat` returns smaller or visibly degraded images;
- final pipeline-ready dimensions and approximate bytes;
- visual comparison and musical comparison against Variant A;
- error rate, cancellation behavior, and timeout/hang absence;
- behavior with limited-library authorization;
- permission complexity and user-facing authorization impact;
- availability and reliability of `PhotosPickerItem.itemIdentifier`;
- implementation complexity and maintenance cost.

A migration proposal remains unsupported unless a PhotoKit candidate has materially better `pipelineReadyDuration` with acceptable dispersion, quality, error rate, iCloud behavior, authorization behavior, and asset-identification feasibility. The current evidence does not support `.fastFormat` as that candidate because the observed output was thumbnail-sized. If evidence is mixed, the decision is `investigate more`. If B/C require unacceptable authorization or fallback complexity, the decision is `keep PhotosPicker` or design a different experiment.

## Recommendation

Do not migrate production import. Keep `PhotosPicker` as the production implementation and close this benchmark as an investigation without an adopted alternative.

Physical-device data confirms severe acquisition tails for Variant A and confirms that the original PhotosPicker-derived B/C route is blocked when `itemIdentifier` is nil. Direct PhotoKit asset data suggests C can produce comparable dimensions quickly for local assets, but it also shows iCloud/network sensitivity and still excludes asset-selection cost. `.fastFormat` is discarded as a comparable pipeline-ready candidate. The PoC cannot conclude that PhotoKit is worth the privacy and complexity increase. A migration proposal is not justified by the current evidence.

## Final Decision

### Decision

Close the experimental benchmark as an investigation completed without migration. `PhotosPicker` remains the production import implementation. The evidence does not justify replacing production import with `PHImageManager`, and this audit does not authorize a roadmap change, ADR, functional-spec change, or production code change.

### Key Evidence

- The perceived delay was reproduced and isolated primarily in `PhotosPickerItem.loadTransferable(Data.self)`.
- Variant A showed fast acquisitions, including approximately 50-199 ms and a latest-round observation around 328 ms, but also tails of approximately 4.28 s and 16.77 s.
- Decode, orientation, resize, and the essential musical pipeline were not large enough to explain those acquisition tails.
- `.fastFormat` acquired quickly, around 3-7 ms, but delivered only approximately 68-120 px on the largest axis. It is not a comparable pipeline-ready substitute for an image near the 1024 px target.
- `.highQualityFormat` delivered 1024x576 or 576x1024 images and showed low latency, approximately 18-26 ms, for already identified local assets.
- `.highQualityFormat` also showed cold/warm behavior, network/local-availability dependence, and failures that need the added PhotoKit callback observability before a future architecture can reason about fallback paths.
- B/C measure `PHImageManager` after a `PHAsset` already exists. They do not include the full selection flow cost or feasibility.
- `PhotosPickerItem.itemIdentifier` was `nil` in physical testing, so the current production picker-mediated flow does not provide a reliable transparent bridge to `PHImageManager`.

### Alternatives Discarded

- `.fastFormat` as a production substitute: discarded because the delivered artifact was thumbnail-sized and not pipeline-ready comparable.
- Direct PhotoKit asset selection as proof of production migration: discarded because it uses a different selection, authorization, privacy, and Limited Library model than production `PhotosPicker`.
- Immediate `.highQualityFormat` migration: discarded because the experiment did not cover the full UX and asset-identification cost, and observed failures/network behavior remain unresolved.

### Remaining Risks

- `PhotosPickerItem.loadTransferable(Data.self)` can still produce user-visible latency tails in production.
- The benchmark did not establish a complete PhotoKit-based user flow that preserves the current privacy model.
- iCloud, Limited Library, denied authorization, fallback UX, and cold-cache behavior remain architecture-level risks for any PhotoKit proposal.
- The prior `.highQualityFormat` failures with `network=false` require the new structured observability for precise diagnosis.

### Future Recommendation

Keep production on `PhotosPicker`. If import latency becomes a priority again, open a new architectural spec rather than extending this experiment. That spec must cover UX, authorization copy, privacy, Limited Library, iCloud/network states, fallback behavior, error observability, and the full cost of obtaining a `PHAsset` before comparing PhotoKit request timings.

### PoC Disposition

The DEBUG-only PoC can be removed later or kept temporarily as a diagnostic tool. If kept, it should remain clearly marked as an experimental benchmark, excluded from release behavior, and not treated as part of the product surface or production import architecture.

## Validation

- Focused benchmark logic tests: passed, 6 tests in `PhotoImportBenchmarkTests` on iPhone 17 Pro simulator after the observability update.
- Physical-device benchmark scenarios: partial; Variant A acquisition tails reproduced, direct PhotoKit asset B/C produced the observations above, and the original PhotosPicker-derived B/C route remains blocked by missing `itemIdentifier`.
- Full simulator suite: not run after this observability and documentation update.
- Debug simulator build: covered by focused test build.
- Release simulator build: not run after this observability and documentation update.
- `git diff --check`: passed.

## Remaining Limitations

- The iCloud wait metric depends on PhotoKit progress callbacks and may remain empty for some iCloud behaviors.
- The prior high-quality failures with `network=false` do not yet have structured `PHImageErrorKey`/in-cloud/callback evidence; observability has been added for the next physical run.
- The benchmark records approximate bytes using different representation boundaries: transferred bytes for A and decoded `CGImage` storage approximation for B/C.
- PhotoKit internals remain opaque; the benchmark compares API-delivered representation and pipeline-ready artifact, not internal implementation work.
- Direct PhotoKit asset runs use a different selector and authorization model than PhotosPicker. They can measure B/C behavior for the same selected `PHAsset`, but they are not a same-flow comparison with Variant A.
- Broader physical-device data is still required for any factual conclusion.

## Cleanup Plan

If the completed diagnostic PoC is no longer useful, remove:

- `snap-battle/Features/Debug/PhotoImportBenchmark/`;
- `snap-battle/Services/Debug/PhotoImportBenchmark/`;
- the `#if DEBUG` launcher in `ContentView`;
- `snap-battleTests/PhotoImportBenchmarkTests.swift`;
- this audit document if no longer desired.

No production flow should require rollback because the existing Capture path is unchanged.
