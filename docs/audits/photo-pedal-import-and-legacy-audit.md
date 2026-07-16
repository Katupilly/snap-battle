# Photo Pedal — Import Performance and Snap Battle Legacy Audit

Date: 2026-07-16  
Scope: diagnostic instrumentation and repository audit only

## 1. Executive Summary

The audit adds DEBUG-only `Logger` and signpost instrumentation without changing the musical algorithm, navigation, persistence contract, target membership, or legacy code. No code was removed, renamed, or cleaned up.

The main confirmed static risk is executor placement: `PhotoPedalViewModel` is `@MainActor`, its `Task` inherits that actor, and `PhotoPedalPipeline` is also `@MainActor`. Therefore the synchronous portions of preparation, fingerprinting, color analysis, sequence generation, and persistence begin on the main executor. This is a risk, not a measured latency result.

The retro processor is explicitly detached at [RetroImageProcessor.swift:46](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Services/ImageProcessing/RetroImageProcessor.swift:46). VisionKit, Vision, and Foundation Models suspend across `await`, but their wall-clock contribution is not yet measured in the real import flow.

The legacy Battle/Creature code is compiled and tested, but no active application route reaches it. It does not have evidence of causing import latency. Reused legacy-named types remain part of the Photo Pedal path and cannot be removed independently.

UIKit is not implicated by current evidence. The required decision is: **insufficient evidence**.

## 2. Instrumentation Added

`PerformanceDiagnostics` in [PerformanceDiagnostics.swift](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Supporting/PerformanceDiagnostics.swift) provides DEBUG-only structured logs and signposts. Release builds emit no diagnostic logs or signposts; diagnostic detail closures are not evaluated there.

The same short run ID is propagated from picker selection through transfer, decode, pipeline, and persistence:

| Stage | Location | Data recorded |
| --- | --- | --- |
| `pickerSelection` | `CaptureView` | executor marker |
| `pickerTransfer` | `CaptureView` | duration, transfer size when complete |
| `imageDecode` | `CaptureViewModel.load` | duration, input bytes, decoded dimensions |
| `imagePreparation` | `PhotoPedalPipeline` / `ImageInputPreparer` | duration, input/original/processed dimensions |
| `fingerprint` | `ImageInputPreparer` | duration, fixed 32-pixel side |
| `retroProcessing` | `PhotoPedalPipeline` | duration, prepared dimensions |
| `colorAnalysis` | `PhotoPedalPipeline` | duration, analysis side |
| `sequenceGeneration` | `PhotoPedalPipeline` | duration, cover dimensions |
| `subjectExtraction` | `PhotoPedalPipeline` | duration |
| `objectAnalysis` | `PhotoPedalPipeline` | duration |
| `metadataGeneration` | `PhotoPedalPipeline` | duration |
| `metadataValidation` | `PhotoPedalPipeline` | duration |
| `persistence` | `CaptureViewModel` / `PedalStore` | duration and encoded byte counts |
| `galleryReload` | `GalleryViewModel` / `PedalStore` | duration, pedal count, issue count |
| `totalPipeline` | `CaptureViewModel` | duration and input dimensions |

No image, pixel buffer, filename, location, user description, Vision label, model prompt, or private metadata is logged.

## 3. Current Import Pipeline

```text
PhotosPickerItem
└─ CaptureView.onChange [CaptureView.swift:143]
   └─ loadTransferable(type: Data.self) [CaptureView.swift:148]
      └─ UIImage(data:) [CaptureViewModel.swift:30]
         └─ PhotoPedalViewModel.process [CaptureViewModel.swift:39]
            └─ PhotoPedalPipeline.run [PhotoPedalPipeline.swift:54]
               ├─ ImageInputPreparer.prepare [ImageInputPreparer.swift:15]
               │  ├─ orientation normalization [ImageInputPreparer.swift:32]
               │  └─ 32×32 fingerprint [ImageInputPreparer.swift:51]
               ├─ RetroImageProcessor.process [PhotoPedalPipeline.swift:62]
               ├─ PhotoColorAnalyzer.analyze [PhotoPedalPipeline.swift:65]
               ├─ ImageSequenceGenerator.makeSequence [PhotoPedalPipeline.swift:68]
               ├─ SubjectExtractionService.extract [PhotoPedalPipeline.swift:75]
               ├─ VisionObjectAnalyzer.analyze [PhotoPedalPipeline.swift:86]
               ├─ FoundationModelsPedalGenerator.generate [PhotoPedalPipeline.swift:89]
               └─ PedalDraftValidator.validate [PhotoPedalPipeline.swift:92]
            └─ PedalStore.save [CaptureViewModel.swift:89]
               └─ Gallery reload after dismissal [GalleryViewModel.swift:45]
                  └─ PedalResultView presentation [CaptureView.swift:120]
```

`PedalResultView` is presented after automatic persistence succeeds. The result view itself does not regenerate the image or musical data.

## 4. Latency Profile

No end-to-end picker exercise was performed in this environment, so real import medians remain `not measured`.

| Stage | Median | Input | Output | Executor |
| --- | ---: | --- | --- | --- |
| PhotosPicker transfer | not measured | Photos asset | `Data` | async PhotosUI task |
| Decode | not measured | `Data` | `UIImage`/`CGImage` | MainActor at call site |
| Preparation | not measured | source image | normalized image + fingerprint | MainActor at call site |
| Retro processing | existing unit-test sample: 185.6 ms average over 5 | prepared image | 160-pixel-wide cover | detached task |
| Color analysis | not measured | prepared image | `PhotoColorProfile` | MainActor at call site |
| Sequence generation | not measured | cover + color profile | persisted musical sequence | MainActor at call site |
| Subject extraction | not measured | prepared image | subject/fallback | async VisionKit API |
| Object analysis | not measured | prepared image + subject | `ObjectObservation` | async Vision API |
| Metadata generation | not measured | observation + harmony | validated draft/fallback | async Foundation Models API |
| Persistence | not measured | pedal + cover | JSON/PNG pair | MainActor at call site in capture flow |
| Gallery reload | not measured | Application Support | ordered stored pedals | detached task in async reload |
| Total import pipeline | not measured | selected image | result view state | inherited MainActor task |

Required scenarios not run: physical device, iCloud asset download, camera-resolution asset, first-run versus warm-run comparison, and three repeated end-to-end imports. The simulator test run exercised deterministic service paths but is not a user-perceived import benchmark.

## 5. MainActor Findings

- `PhotoPedalViewModel` is `@MainActor` at [CaptureViewModel.swift:4](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Features/Capture/CaptureViewModel.swift:4).
- `Task` created in `process` inherits the MainActor because it is created from that isolated method [CaptureViewModel.swift:43](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Features/Capture/CaptureViewModel.swift:43).
- `PhotoPedalPipeline` is `@MainActor` [PhotoPedalPipeline.swift:3](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Services/Pedal/PhotoPedalPipeline.swift:3).
- `ImageInputPreparer.prepare`, fingerprint rendering, `PhotoColorAnalyzer.analyze`, `ImageSequenceGenerator.makeSequence`, and synchronous `PedalStore.save` have no executor hop of their own.
- `RetroImageProcessor.process` uses `Task.detached` [RetroImageProcessor.swift:48](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Services/ImageProcessing/RetroImageProcessor.swift:48), so its pixel work is not evidence of MainActor blocking.
- `UIImage` is carried through `PreparedImage` as `@unchecked Sendable` [ImageInputPreparer.swift:5](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Services/ImageInputPreparer.swift:5). This is an existing concurrency boundary and should be addressed only with a specific image-concurrency design, not with indiscriminate detached tasks.
- `isProcessing` prevents duplicate calls from the view model [CaptureViewModel.swift:40](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Features/Capture/CaptureViewModel.swift:40).
- Gallery reload can occur on initial load, result dismissal, and result completion. This is observable duplicate work around reload, but its cost is not measured yet.

## 6. Decode and Memory Findings

- `UIImage(data:)` decodes the selected `Data` before the pipeline starts [CaptureViewModel.swift:30](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Features/Capture/CaptureViewModel.swift:30).
- The current pipeline retains the decoded/normalized image, creates a normalized render for non-up orientation, creates a 32×32 fingerprint buffer, creates a 160-pixel-wide cover buffer, and creates a 64×64 color-analysis buffer.
- Sequence generation renders the cover once at full cover dimensions and once at 16×8 tone-grid dimensions [ImageSequenceGenerator.swift:49](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Services/Pedal/ImageSequenceGenerator.swift:49).
- Persisting the cover calls `pngData()` and then reloads the written pair for validation [PedalStore.swift:106](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Services/Persistence/PedalStore.swift:106). This is a real encode/decode path, but its duration is not measured yet.
- The code does not use ImageIO downsampling or file representation for picker imports. Whether full-resolution decoding is materially harmful depends on actual selected asset dimensions and must be measured first.
- Vision receives the prepared `UIImage` as a `CGImage`; there is no separate Vision-resolution representation today [VisionObjectAnalyzer.swift:6](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Services/Vision/VisionObjectAnalyzer.swift:6).

Potential future optimizations, not implemented here: ImageIO downsampling, a bounded intermediate representation, reuse of a shared `CGImage`, and separating Vision resolution from cover/music resolution.

## 7. Legacy Inventory

The app target uses `PBXFileSystemSynchronizedRootGroup` for the complete `snap-battle/` directory [project.pbxproj:41](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle.xcodeproj/project.pbxproj:41). Thus legacy Swift files remain compiled even though the application source build phase has no individual file entries.

| Area | Classification | Runtime impact | Removal risk | Evidence |
| --- | --- | --- | --- | --- |
| `ObjectObservation` | Reused by Photo Pedal | confirmed dependency, no separate startup work | high | consumed by Vision and metadata generator |
| `CreatureMaterial` | Reused by Photo Pedal | type/data dependency only | high | stored in `ObjectObservation` and inferred by `VisionObjectAnalyzer` |
| `SubjectExtracting` / `ObjectAnalyzing` | Reused by Photo Pedal | service calls in import pipeline | high | protocols are declared in `Services/Pipeline.swift` and used by `PhotoPedalPipeline` |
| `AppError` | Reused by Photo Pedal | error construction/reporting | high | used across image, Vision, metadata, camera, and persistence paths |
| `RetroImageConfiguration.snapBattle` | Naming-only legacy | none at runtime beyond static configuration lookup | medium | current retro behavior uses the value, but only the label is old |
| `CreaturePipeline` and `PipelineResult` | Isolated legacy | no active route found | unknown | `Services/Pipeline.swift`; protocols in the same file are still reused |
| `Domain/Creature*` | Isolated legacy | no active route found | unknown | referenced by legacy pipeline, Battle, and tests |
| `Domain/Battle/*` | Isolated legacy | no active route found | unknown | referenced by Battle engine/UI/tests only |
| `Features/Battle/*` | Build/test/debug-only legacy | no active root navigation route found | unknown | `BattleDebugLauncher` has no reference from `ContentView` |
| `Features/Generation/*` and `Features/Result/*` | Isolated legacy | no active route found | unknown | old Creature UI types only |
| `Services/Battle/*` | Isolated legacy | no active route found | unknown | referenced by Battle tests/UI |
| `Services/GameRules/*` | Isolated legacy | no active Photo Pedal dependency | unknown | consumes Creature types and legacy tests |
| `FoundationModelsCreatureGenerator` / `MockCreatureGenerator` | Isolated/build-test legacy | no active runtime call found | unknown | old `CreatureGenerating` protocol and tests |
| `PipelineDiagnostics` / `DiagnosticRun` | Build/test legacy | no Photo Pedal runtime use found | medium | diagnostics model stores Creature-era fields; current pedal path uses new signposts |
| `snap-battle` target, `snap_battleApp`, `snap-battleTests` | Naming-only legacy | app identifier/build metadata impact only | medium | names appear in project, app type, tests, and docs |
| `CreatureAuditTests`, Battle test suites | Build/test-only legacy | no app runtime impact | medium | explicitly listed in test target Sources phase |

No asset, string, reflection lookup, or App Intent route was found that activates Battle/Creature UI during the current Photo Pedal import flow. The synchronized source group means “not referenced by ContentView” is not equivalent to “not compiled.”

## 8. Reused Legacy Components and Dependency Graph

```text
Photo Pedal flow
├── current-native components
│   ├── PhotosUI / SwiftUI capture
│   ├── PhotoPedalViewModel
│   ├── PhotoPedalPipeline
│   ├── RetroImageProcessor
│   ├── PhotoColorAnalyzer / ImageSequenceGenerator
│   ├── PedalStore / PhotoPedalSynth
│   └── PedalResultView / Gallery
├── legacy-named but reused components
│   ├── ObjectObservation
│   ├── CreatureMaterial
│   ├── SubjectExtracting
│   ├── ObjectAnalyzing
│   └── AppError
└── isolated Snap Battle components
    ├── Creature domain and CreaturePipeline
    ├── Battle domain, services, UI, and fixtures
    ├── Creature Foundation Models generators
    └── legacy creature diagnostics and tests
```

The key coupling is that `SubjectExtracting` and `ObjectAnalyzing` are declared in the same source file as `CreaturePipeline`. Future removal would first need a small extraction/specification boundary, not deletion of that file.

## 9. Performance × Legacy Correlation

| Hypothesis | Result | Evidence |
| --- | --- | --- |
| Battle/Creature code initializes at app startup | not observed statically | `snap_battleApp` creates only `ContentView`; no Battle model/store is constructed there |
| Legacy ViewModels/stores are created in root | discarded | root creates `AppNavigationModel` and `GalleryViewModel`; Gallery creates current `PhotoPedalSynth` |
| Legacy assets load during import | not measured | no asset load from the active pipeline was found |
| Legacy routes remain in `ContentView` | discarded | active destinations are Gallery and Jam; Capture is a sheet |
| Legacy observers are active | discarded for Battle/Creature | current audio observer belongs to `PhotoPedalSynth`, which is current runtime code |
| Legacy tests/fixtures affect runtime | discarded | test target membership does not affect app execution |
| Reused legacy services add unnecessary work | needs device profiling | VisionKit subject extraction and Vision classification are active, but product intent still requires metadata context |
| Gallery reload duplicates perceived work | confirmed statically, latency unmeasured | reload occurs on launch and after result completion/dismissal |

Conclusion: legacy code is a build/maintenance risk and may affect binary/build size, but there is no evidence it causes the import slowdown. The active semantic-analysis stages may contribute materially; signposts now distinguish them from synchronous image work.

## 10. System Log Assessment

No provided system log is sufficient to explain latency without a matching run ID and signpost interval.

| Log | Classification |
| --- | --- |
| `FigXPCUtilities` / `FigCaptureSourceRemote -17281` | likely simulator/framework camera noise; potentially relevant only to camera capture, not PhotosPicker import |
| `Visual isTranslatable: noObservations` | likely Vision/VisualTranslation framework noise; not proof of Photo Pedal failure |
| `MADService XPC invalidated` | likely simulator/audio framework noise; no evidence tied to import pipeline |
| `fopen errno 2` | insufficient evidence; could be framework or missing optional resource |
| `mobile.usermanagerd XPC` | likely simulator/system service noise |
| `LaunchServices -54` | likely simulator/system registration noise |

The test run reproduced VisionKit/VisualTranslation and simulator framework warnings while all 72 tests passed. They are therefore not treated as the primary performance explanation.

## 11. UIKit Decision

**insufficient evidence**

The active flow already uses SwiftUI with PhotosUI and only uses UIKit for image/audio/platform bridges. No SwiftUI body, navigation update, or view diff has been correlated with the import delay. A UIKit investigation is not justified by the current evidence.

## 12. Minimal Performance Plan

1. Capture three or more real imports on a physical device with local small, camera, high-resolution, and iCloud-backed assets; record medians from the new signposts.
2. Compare the synchronous MainActor intervals against the suspended VisionKit, Vision, Foundation Models, transfer, and persistence intervals.
3. If decode dominates, evaluate ImageIO file representation/downsampling in a separate approved change.
4. If semantic analysis dominates, measure fallback and unavailable-model paths before deciding whether parallelism or a reduced analysis representation is appropriate.
5. If reload dominates or duplicates after completion, address it in a separate navigation/persistence change with behavior-focused tests.
6. Keep legacy cleanup in separate reversible specifications: isolated Battle UI/routes, isolated Creature domain/tests, reused-type renaming, asset/fixture removal, and project/target renaming.

## Validation

- Debug simulator build: passed.
- Full simulator suite on iPhone 17 Pro, iOS 26.5: passed, 72 tests in 7 suites.
- `git diff --check`: passed.
- Release simulator build: passed.
- Physical-device import, camera, iCloud transfer, live Foundation Models, Instruments trace, and three-repeat latency medians: `not run`.

## Scope Left Unchanged

No legacy code, assets, routes, target membership, names, navigation, persistence behavior, image algorithm, musical algorithm, or framework architecture was removed or migrated. No commit was created.
