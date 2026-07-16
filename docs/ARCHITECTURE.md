# Architecture

## Current Shape

The `snap-battle` app target is a SwiftUI app. `snap_battleApp` presents `ContentView`, whose active flow enters `Features/Capture/CaptureView.swift`. `PhotoPedalViewModel` owns capture state, the current `PhotoPedal`, `PhotoPedalSynth`, and `PedalStore` coordination. `PedalResultView` presents the result and playback controls.

```text
Captured or imported image
-> ImageInputPreparer
-> RetroImageProcessor and PhotoColorAnalyzer
-> ImageSequenceGenerator
-> PhotoPedalPipeline
-> PedalStore / PhotoPedalSynth / PedalResultView

VisionKit + Vision -> FoundationModelsPedalGenerator -> name and description
```

## Responsibilities

| Area | Current files/types |
| --- | --- |
| App and routing | `snap_battleApp.swift`, `ContentView`, `AppIntentRouter` |
| Capture and view state | `Features/Capture/CaptureView.swift`, `CaptureViewModel.swift`, `CameraPicker.swift` |
| Presentation | `Features/Pedal/PedalResultView.swift` |
| Domain | `Domain/Pedal/Pedal.swift` |
| Input and cover processing | `Services/ImageInputPreparer.swift`, `Services/ImageProcessing/RetroImageProcessor.swift` |
| Music generation | `Services/Pedal/PhotoColorAnalyzer.swift`, `ImageSequenceGenerator.swift`, `PedalHeuristics.swift`, `PhotoPedalPipeline.swift` |
| Audio | `Services/Audio/PhotoPedalSynth.swift` |
| Persistence | `Services/Persistence/PedalStore.swift` |
| Metadata | `Services/Vision/`, `Services/FoundationModels/FoundationModelsPedalGenerator.swift` |
| Shortcuts | `Intents/PhotoPedalIntents.swift` |

Dependencies currently flow from SwiftUI views to `PhotoPedalViewModel`, then to pipeline, storage, and audio services. Services construct and consume domain values; SwiftUI views present and forward user actions. `PhotoPedalViewModel` currently bridges UI, services, storage, and playback, so it is the main state owner for the active flow.

## Persistence Boundary

`PedalStore` writes `latest-pedal.json` and `latest-pedal.png` in Application Support. It is not a gallery repository and does not store originals, fingerprints, Vision observations, or generator versions.

## Platform Integrations

UIKit/AVFoundation support camera capture; PhotosUI imports images; Vision/VisionKit provide naming context; Foundation Models supplies semantic metadata; AVFoundation renders audio; App Intents routes shortcuts into the foreground app.

## Legacy Pivot Debt

The app target still compiles unreachable Snap Battle code: `Creature*` domain/services, `Services/Battle/`, `Features/Generation/`, `Features/Result/`, and `Features/Battle/`. Legacy tests and names (`snap-battle`, `snap_battleApp`, `RetroImageConfiguration.snapBattle`) also remain. This documentation does not treat that code as Photo Pedal architecture; migration or removal requires a separately approved specification.
