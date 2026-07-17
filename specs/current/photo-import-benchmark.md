# Photo Import Benchmark PoC

Status: Completed
Priority: P0 Experimental
Last updated: 2026-07-17

## Context

Photo Pedal currently imports library photos through `PhotosPickerItem.loadTransferable(type: Data.self)`, decodes the data into an image, and sends that image through the current image preparation, cover, color, sequence, and essential pedal result path.

Recent diagnostics identify `pickerTransfer` as variable and external to the core pipeline. Physical-device measurements reproduced severe tails in the current `PhotosPickerItem.loadTransferable(type: Data.self)` acquisition path:

- fast acquisitions of approximately 50-199 ms;
- a latest-round acquisition of approximately 328 ms;
- a slow acquisition of approximately 4,284 ms;
- an extreme acquisition of approximately 16,774 ms;
- the main observed bottleneck concentrated in `acquisitionDuration`, with later normalization to a max-1024 px image remaining approximately 37-313 ms.

The original benchmark assumed that the same user-selected `PhotosPickerItem` could drive A/B/C by resolving `PhotosPickerItem.itemIdentifier` into a `PHAsset`. Physical-device testing invalidated that premise: `PhotosPickerItem.itemIdentifier` remained `nil` for measured selections even when PhotoKit authorization was `authorized`. Consequently, the original PhotoKit variants did not execute and ended as `missingItemIdentifier`.

The hypothesis for the remaining experiment is split in two. First, the PhotosPicker benchmark measures the current production-style import path and its acquisition tails. Second, the PhotoKit asset benchmark measures whether `PHImageManager` can quickly produce suitable fixed-size images after a `PHAsset` has already been identified by a separate DEBUG-only selector. The PhotoKit asset benchmark does not measure the same selection flow, authorization flow, or privacy model as the current `PhotosPicker` path.

This specification authorizes only an isolated DEBUG-only proof of concept to collect evidence. It does not authorize a production migration.

## Objective

Create a removable DEBUG-only benchmark surface that distinguishes two experimental flows:

1. `PhotosPicker Benchmark`;
2. `PhotoKit Asset Benchmark`.

The benchmark must treat the image returned by each strategy as the canonical image for that run. It must measure performance and compare visual and musical outputs without modifying the app's production capture, persistence, navigation, Gallery, Jam, App Intents, metadata, cover, fingerprint, or music algorithms.

A, B, and C no longer necessarily share the same mechanism of selection. B/C must not be treated as transparent substitutes for A unless a later architecture can account for asset identification, authorization, privacy, limited-library behavior, and fallback complexity.

## DEBUG-Only Scope

All app code for the benchmark must compile and be reachable only in DEBUG builds. Release builds must not expose the benchmark UI, run benchmark instrumentation, require additional photo-library authorization because of the benchmark, or change the existing import behavior.

Allowed implementation areas:

- new files under `snap-battle/Features/Debug/PhotoImportBenchmark/`;
- new files under `snap-battle/Services/Debug/PhotoImportBenchmark/`;
- focused tests for benchmark logic that does not require PhotoKit runtime;
- `docs/audits/photo-import-benchmark.md`;
- minimal DEBUG-only launcher wiring if necessary;
- project membership implied by the synchronized app source group.

## Out Of Scope

- Replacing the production `PhotosPicker` import path.
- Adding automatic fallback between strategies.
- Using `.opportunistic` delivery mode.
- Swapping a higher-quality image after a run has generated a pedal.
- Changing image preparation, visual algorithm, music algorithm, fingerprint calculation, cover generation, persistence, metadata enrichment, Gallery, Jam, App Intents, or navigation model.
- Changing production privacy strings or production authorization behavior unless the benchmark cannot compile without an existing platform-required string.
- Adding asset caches, download managers, background downloads, new persistence, new metadata, or dependencies.
- Recording image content, filenames, locations, EXIF, generated semantic metadata, or other personal data in logs.
- Correlating a `PhotosPickerItem` to a `PHAsset` by filename, hash, creation date, dimensions, image content, or any other inferred identity.
- Creating an ADR or recording `PHImageManager` as an accepted architecture decision.
- Changing roadmap or functional specs.

## Strategies

### PhotosPicker Benchmark

This flow represents the current production-style library import mechanism.

Use `PhotosPickerItem.loadTransferable(type: Data.self)`, decode into the canonical image for the run, normalize orientation, bound the pipeline-ready artifact to the documented max dimension, and execute the current essential result path. This flow does not depend on `PHAsset` and does not require PhotoKit library authorization to browse the picker.

Metrics for this flow include acquisition duration, pipeline-ready duration, end-to-end duration, dimensions, approximate transferred bytes, callbacks when available, errors, and cancellations.

### PhotoKit Asset Benchmark

This flow uses a directly selected `PHAsset` from a DEBUG-only experimental PhotoKit interface.

Variants B and C run against the same selected `PHAsset` when the tester keeps the same asset selected:

- Variant B: request an image from `PHImageManager` with `PHImageRequestOptions.deliveryMode = .fastFormat`, a fixed documented target size, appropriate resize mode, and configurable network access. The delivered image is canonical for that run and must not be replaced by a later higher-quality representation.
- Variant C: request an image from `PHImageManager` with `.highQualityFormat`, the same fixed target size, documented network behavior, and no `.opportunistic` mode. The delivered image is canonical for that run.

This flow measures `PHImageManager` after an asset has already been identified. It does not represent the same selection mechanism, authorization behavior, limited-library behavior, or privacy model as Variant A. B/C timing must not be interpreted as the full cost of replacing `PhotosPickerItem.loadTransferable(Data.self)`, because it excludes the architectural cost of locating or obtaining a `PHAsset` from the user-facing PhotosPicker flow.

Latest physical evidence narrows the candidate set:

- `.fastFormat` returned thumbnails of only 68-120 px on the largest axis despite `targetSize=1024x1024`. It did not satisfy the benchmark intent of a pipeline-ready image near the 1024 px limit, so its 3-7 ms acquisition times are not comparable to A or C as equivalent-quality results.
- `.highQualityFormat` returned 1024x576 or 576x1024 images. It is the only observed PhotoKit candidate that produced the intended comparable artifact.
- `.highQualityFormat` acquired local assets in approximately 18-26 ms.
- `.highQualityFormat` failed for some assets with `network=false`; structured failure details require another run with the added observability.
- With `network=true`, one `.highQualityFormat` cold acquisition took approximately 2,180 ms and the warm repeat took approximately 12 ms.
- B/C still do not include the cost of arriving at a `PHAsset`.

### Original PhotosPicker Item Identifier Route

The original route attempted:

`PhotosPickerItem -> itemIdentifier -> PHAsset`

Physical-device testing found `itemIdentifier == nil` for measured selections, even with PhotoKit authorization `authorized`. This is a factual result and an architecturally relevant limitation. When `itemIdentifier` is nil, B/C through this route are unavailable and must record `missingItemIdentifier`. The benchmark must not invent identifiers and must not correlate assets by filename, hash, date, dimensions, or content.

## Target Size Rule

Before choosing the benchmark target size, inspect the current implementation requirements for:

- Vision input resolution;
- cover generation resolution;
- color analysis resolution;
- musical grid resolution;
- fingerprint resolution.

The selected target size must be fixed, documented, shared by Variant B and Variant C, smaller than the original when possible, and sufficient for the current perceptual cover and deterministic musical path. It must not be chosen arbitrarily.

## Metrics Collected

For each run ID, collect DEBUG-only `Logger` entries and signposts for:

- strategy;
- benchmark flow;
- permission state;
- item identifier availability;
- direct PhotoKit asset selection availability;
- target size;
- source dimensions when known;
- delivered dimensions;
- network access enabled or disabled;
- transfer or PhotoKit request duration;
- image decode or conversion duration;
- essential pipeline duration;
- total duration;
- degraded/final flag when provided by PhotoKit;
- PhotoKit request ID for callback/failure correlation;
- PhotoKit callback count;
- PhotoKit progress callback count and progress values when available;
- `PHImageErrorKey`, sanitized to domain and code rather than raw personal context;
- `PHImageCancelledKey`;
- `PHImageResultIsInCloudKey`;
- `PHImageResultIsDegradedKey`;
- final structured reason for success, cancellation, no result, or PhotoKit failure;
- cancellation;
- error category.

Product comparison metrics:

- time to usable canonical image;
- time to essential result;
- total time;
- first run versus warm runs;
- local versus iCloud behavior;
- network enabled versus disabled behavior;
- delivered dimensions;
- cover dimensions and visual comparison;
- pixel equivalence when applicable;
- orientation stability;
- fingerprint;
- `PhotoColorProfile`;
- `PedalHarmony`;
- `PedalSequence`;
- `PedalSoundProfile`.

The benchmark must not log image bytes, pixel buffers, filenames, locations, EXIF, generated names, generated descriptions, prompts, or Vision labels.

For direct PhotoKit asset runs, DEBUG logs may record the selected `PHAsset.localIdentifier`, asset dimensions, authorization state, and asset availability to prove that B/C used the same selected asset. These identifiers must not be displayed as user-facing comparison evidence, stored permanently, or integrated into production Capture.

## Test Scenarios

Physical-device benchmark scenarios for the PhotosPicker benchmark:

1. small local photo;
2. recent camera photo;
3. high-resolution photo;
4. confirmed iCloud-backed photo;
5. same photo first run;
6. same photo warm run;
7. limited library access;
8. missing `itemIdentifier`, when reproducible.

Physical-device benchmark scenarios for the PhotoKit asset benchmark:

1. small local asset;
2. recent camera asset;
3. high-resolution asset;
4. confirmed iCloud-backed asset;
5. same asset first run;
6. same asset warm run;
7. limited library access;
8. network disabled and enabled runs where applicable.

For each reproducible scenario and strategy, run at least three times, record approximate median, min, max, run count, delivered size, failures, and cancellations. Mark unavailable scenarios as `not run` rather than inferring results. Keep the PhotosPicker and PhotoKit asset results separated in reporting.

## Controls To Reduce Variables

- Use the same selected item for PhotosPicker runs where applicable.
- Use the same selected `PHAsset` for B and C in PhotoKit asset runs.
- Do not claim that A/B/C share the same selection mechanism unless `PhotosPickerItem.itemIdentifier` is available and resolves to a `PHAsset`.
- Use the same fixed target size for both PhotoKit variants.
- Do not use `.opportunistic` delivery, because it may produce multiple images and confound the canonical representation rule.
- Treat exactly one delivered image as canonical per run.
- Do not perform a quality upgrade or second generation after a run completes.
- Keep the current essential pipeline unchanged for all variants after canonical image acquisition.
- Compare musical identity using deterministic musical data only, excluding UUID, `createdAt`, generated names, descriptions, and other semantic metadata.
- Separate first-run and warm-run measurements.
- Separate network enabled and disabled measurements for PhotoKit variants.
- Record authorization and limited-access state with each run.
- Separate performance of the import mechanism from performance of the complete user-facing flow.

## Privacy And Authorization Risks

The benchmark must explain in UI and documentation that `PHImageManager` requires PhotoKit library authorization beyond the current picker-only user experience. It must measure and display authorization outcomes:

- authorized;
- limited;
- denied or restricted;
- not determined;
- missing item identifier;
- unresolved asset;
- iCloud asset with network disabled;
- iCloud asset with network enabled.

The production app's privacy model must remain unchanged in this step. Any future migration proposal must separately justify the increased permission surface, limited-library behavior, fallback rules, and user-facing copy.

Direct PhotoKit asset selection is an experimental DEBUG-only measuring tool. It is not production Capture, not a transparent replacement for PhotosPicker, and not evidence by itself that the app can obtain the same asset from the current picker-mediated UX.

## Physical Evidence To Date

Physical-device evidence currently supports only these facts:

- `PhotosPickerItem.loadTransferable(Data.self)` can be fast, with observed acquisitions around 50-199 ms.
- The same path can produce severe acquisition tails, with observed acquisitions around 4,284 ms and 16,774 ms. The latest round observed approximately 328 ms.
- The bottleneck in those runs was concentrated in `acquisitionDuration`; later work to reach a normalized max-1024 px image was approximately 37-313 ms.
- `photoKitFastFormat` and `photoKitHighQuality` did not execute through the original PhotosPicker-derived route because `PhotosPickerItem.itemIdentifier` was nil; both ended as `missingItemIdentifier`.
- Direct `PhotoKit asset benchmark` runs showed `photoKitFastFormat` acquiring in approximately 3-7 ms, but only delivering 68-120 px thumbnails. This is not a comparable pipeline-ready artifact and should not be compared directly with A or C as equivalent quality.
- Direct `PhotoKit asset benchmark` runs showed `photoKitHighQuality` delivering 1024x576 or 576x1024 images. Local-asset acquisition was approximately 18-26 ms.
- `photoKitHighQuality` failed for some assets with `network=false`. With `network=true`, one cold acquisition was approximately 2,180 ms and its warm repeat was approximately 12 ms.
- The B/C data still excludes the cost of obtaining or selecting a `PHAsset`.
- There is not yet comparable same-flow evidence supporting a migration.

## Criteria Of Success

The PoC succeeds as an experiment if it produces comparable data for the required strategies, preserves isolation from production behavior, and documents enough evidence to choose one of:

- keep `PhotosPicker`;
- investigate alternatives;
- propose a later architectural change specification.

The data supports a future architectural change proposal only if the evidence separates:

- performance of `PhotosPickerItem.loadTransferable(Data.self)`;
- performance of `PHImageManager` once a `PHAsset` is already available;
- the missing cost and feasibility of obtaining a `PHAsset` from an acceptable user-facing flow.

Any future proposal must consider not only timing, but also authorization, privacy, limited-library behavior, absence or unreliability of `itemIdentifier`, implementation complexity, fallback behavior, iCloud/network states, visual quality, and musical stability.

## Criteria Of Discard

Discard the PhotoKit fast-format direction if:

- `.fastFormat` continues to return thumbnail-sized artifacts rather than a pipeline-ready image near the 1024 px target;
- speed gains are small, inconsistent, or mostly disappear after warm runs;
- delivered images cause material cover or music differences;
- `itemIdentifier` or asset resolution is unreliable;
- direct PhotoKit asset timings cannot be connected to an acceptable full UX flow;
- limited-library, denied, iCloud, or network-disabled states create unacceptable fallback complexity;
- the benchmark cannot remain DEBUG-only and removable;
- the permission increase is not justified by measured product benefit.

## Final Conclusion

The experimental investigation is complete and does not justify a production migration.

The perceived import delay was reproduced on physical device and isolated primarily to `PhotosPickerItem.loadTransferable(Data.self)`. The same path produced fast acquisitions, including approximately 50-199 ms and a latest-round observation of approximately 328 ms, but also severe tails of approximately 4.28 s and 16.77 s. The measured decode, orientation, resize, and essential musical pipeline work remained much smaller than those tails and does not explain the perceived delay.

The PhotoKit alternatives did not provide a transparent production replacement:

- `.fastFormat` is discarded as a comparable pipeline-ready substitute because it delivered thumbnails of only approximately 68-120 px on the largest axis, despite the `1024x1024` target. Its very low acquisition time is not comparable to A or C as equivalent-quality output.
- `.highQualityFormat` delivered images near the intended 1024 px target, including 1024x576 and 576x1024, and showed low latency for already identified local assets, approximately 18-26 ms.
- `.highQualityFormat` still showed cold/warm behavior, local-availability and network dependence, and failures that require the added observability before any architectural proposal could reason about fallback behavior.

B/C measure `PHImageManager` only after a `PHAsset` has already been obtained. They do not include the cost, UX, authorization, privacy, Limited Library behavior, iCloud behavior, fallback design, or reliability of obtaining that `PHAsset` from a real user-facing flow. In physical testing, `PhotosPickerItem.itemIdentifier` was `nil`, so there is currently no reliable and transparent transition from the picker-mediated production flow to `PHImageManager`.

Therefore, `PhotosPicker` remains the production implementation. The DEBUG-only PoC may be kept temporarily as a diagnostic tool or removed later, but it is not part of the product direction. Any future proposal to migrate from `PhotosPicker` to PhotoKit requires a new architectural specification covering UX, authorization, privacy, Limited Library, iCloud, fallback behavior, error observability, and the full cost of obtaining a `PHAsset`.

## Deliverables

- DEBUG-only benchmark UI that clearly separates `PhotosPicker Benchmark` from `PhotoKit Asset Benchmark`, runs Variant A from PhotosPicker, runs B/C from a directly selected `PHAsset`, repeats runs, clears results, views timings, dimensions, 2-bit cover, fingerprints, and musical comparisons.
- DEBUG-only benchmark services for strategy execution, metrics, output comparison, authorization reporting, logging, and signposts.
- Focused tests for non-PhotoKit runtime logic such as metrics formatting, grouping, output comparison, single-canonical-image protection, cancellation categorization, and missing item identifier fallback.
- `docs/audits/photo-import-benchmark.md` containing objective, architecture, variants, target size, authorization model, scenarios, results, limitations, recommendation, next steps, and cleanup plan.

## Validation

Run and report:

- focused benchmark logic tests;
- full simulator suite;
- Debug build;
- Release build;
- `git diff --check`.

Physical device validation is required for factual benchmark conclusions. If physical validation is absent or cannot connect PhotoKit asset timing to an acceptable complete UX flow, the recommendation must be `insufficient evidence` or `investigate alternatives`, and no migration should be proposed.

## Cleanup Plan

If not adopted, remove:

- `snap-battle/Features/Debug/PhotoImportBenchmark/`;
- `snap-battle/Services/Debug/PhotoImportBenchmark/`;
- any DEBUG-only launcher wiring;
- focused benchmark tests;
- `docs/audits/photo-import-benchmark.md` if it is no longer wanted as an audit artifact.

Because the app source group is synchronized, removal should not require manual project-file source membership cleanup unless launcher wiring touched explicit project settings. No production code path should need rollback because none is replaced by this PoC.

## Implementation Authorization

This completed experimental specification authorized only the DEBUG-only benchmark PoC described above. It does not authorize production migration to `PHImageManager`, roadmap changes, changes to existing functional specs, an ADR, or changes to current Photo Pedal output algorithms.
