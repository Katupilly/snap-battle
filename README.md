# Photo Pedal

Photo Pedal is an iOS prototype that turns a captured or imported photo into a playable musical object. The current flow is:

`photo input -> image preparation -> 2-bit cover -> deterministic note sequence -> synth playback -> name and description -> saved pedal`

The app is an MVP. A roadmap item is not necessarily implemented; see [the roadmap](docs/ROADMAP.md) and active specifications before starting feature work.

## Requirements

- Xcode 26.5 or later
- iOS 26.5 or later
- A physical iPhone for camera, VisionKit, audio, and Apple Foundation Models validation
- Apple Intelligence and a supported current locale for pedal metadata generation

The project uses Swift, SwiftUI, PhotosUI, AVFoundation, Vision, VisionKit, Apple Foundation Models, App Intents, and Swift Testing. The project is `snap-battle.xcodeproj`; its names remain from the pre-pivot project.

## Repository Overview

- `snap-battle/`: app target, including capture, pedal presentation, domain types, and services
- `snap-battleTests/`: current Swift Testing target; it also contains legacy game tests
- `docs/`: product, architecture, contracts, validation, and decisions
- `specs/`: active and planned feature specifications

## Build And Test

Open `snap-battle.xcodeproj` in Xcode and run the `snap-battle` scheme. To test against an installed simulator:

```sh
xcodebuild test -project "snap-battle.xcodeproj" -scheme "snap-battle" -destination 'platform=iOS Simulator,name=<installed simulator>'
```

Device-only integrations require manual validation. See [Testing](docs/TESTING.md) and [Device validation](docs/DEVICE_VALIDATION.md).

## MVP Status

Implemented: camera or photo-library input, 2-bit cover processing, deterministic music generation, local synth playback, reverb/distortion selection, locally persisted latest pedal, Foundation Models metadata, and two App Intents.

Not implemented: generator versioning, a persistent gallery, boards, sharing, collaboration, offline rendering, video export, and the roadmap's effect macro labels.

## Documentation

- [Agent instructions](AGENTS.md)
- [Product specification](docs/PRODUCT_SPEC.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Data model](docs/DATA_MODEL.md)
- [Image-to-music generation](docs/IMAGE_TO_MUSIC.md)
- [Audio system](docs/AUDIO_SYSTEM.md)
- [Foundation Models integration](docs/FOUNDATION_MODELS.md)
- [App Intents](docs/APP_INTENTS.md)
- [Testing](docs/TESTING.md)
- [Device validation](docs/DEVICE_VALIDATION.md)
- [Roadmap](docs/ROADMAP.md)
- [Feature specifications](specs/README.md)
- [Architecture decisions](docs/decisions/README.md)
