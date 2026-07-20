# Architecture

## Current Shape

The `Dap` app target is a SwiftUI app. `DapApp` presents `ContentView`, whose active flow enters `Features/Capture/CaptureView.swift`. `DapViewModel` owns capture state, the current `PhotoPedal`, `DapSynth`, and `PedalStore` coordination. `PedalResultView` presents the result and playback controls.

```text
Captured or imported image
-> ImageInputPreparer
-> RetroImageProcessor and PhotoColorAnalyzer
-> ImageSequenceGenerator
-> DapPipeline
-> PedalStore / DapSynth / PedalResultView

VisionKit + Vision -> FoundationModelsPedalGenerator -> name and description
```

## Responsibilities

| Area | Current files/types |
| --- | --- |
| App and routing | `DapApp.swift`, `ContentView`, `AppIntentRouter` |
| Capture and view state | `Features/Capture/CaptureView.swift`, `CaptureViewModel.swift`, `CameraPicker.swift` |
| Presentation | `Features/Pedal/PedalResultView.swift` |
| Domain | `Domain/Pedal/Pedal.swift` |
| Input and cover processing | `Services/ImageInputPreparer.swift`, `Services/ImageProcessing/RetroImageProcessor.swift` |
| Music generation | `Services/Pedal/PhotoColorAnalyzer.swift`, `ImageSequenceGenerator.swift`, `PedalHeuristics.swift`, `DapPipeline.swift` |
| Audio | `Services/Audio/DapSynth.swift` |
| Persistence | `Services/Persistence/PedalStore.swift` |
| Metadata | `Services/Vision/`, `Services/FoundationModels/FoundationModelsPedalGenerator.swift` |
| Shortcuts | `Intents/PhotoPedalIntents.swift` |

Dependencies currently flow from SwiftUI views to `DapViewModel`, then to pipeline, storage, and audio services. Services construct and consume domain values; SwiftUI views present and forward user actions. `DapViewModel` currently bridges UI, services, storage, and playback, so it is the main state owner for the active flow.

## Persistence Boundary

`PedalStore` is the local collection boundary. It stores one validated JSON/PNG pair per pedal UUID in Application Support, derives collection cover paths from the UUID, and migrates the preserved `latest-pedal.json`/`latest-pedal.png` pair when valid. It does not store originals, fingerprints, Vision observations, or generator versions.

## Platform Integrations

UIKit/AVFoundation support camera capture; PhotosUI imports images; Vision/VisionKit provide naming context; Foundation Models supplies semantic metadata; AVFoundation renders audio; App Intents routes shortcuts into the foreground app.

## Legacy Pivot Debt

### Legacy But Still Reused

`ObjectObservation`, `CreatureMaterial`, `SubjectExtracting`, `ObjectAnalyzing`, and `AppError` retain game-era names or relationships but participate in the current metadata/input flow. Their removal safety is unknown and requires reference, target-membership, and test analysis.

### Legacy And Apparently Isolated

The target also compiles legacy `Creature*` domain/services, `Services/Battle/`, `Features/Generation/`, `Features/Result/`, and `Features/Battle/`. These areas are not reached from the active Dap flow, but this observation alone does not make them safe to remove because target membership and tests still compile them.

### Naming Legacy

Legacy tests and names include `DapApp` and `RetroImageConfiguration.fourToneRetro`.

Legacy cleanup requires a dedicated audit and an approved cleanup spec.
