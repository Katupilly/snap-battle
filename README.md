# Photo Pedal

Photo Pedal is an iOS prototype that turns photos into small, collectible musical objects. Each photo becomes a processed 2-bit cover image, a deterministic music recipe, a note sequence, an effect with parameters, and a generated name and description.

The product direction is documented in [`docs/ROADMAP.md`](docs/ROADMAP.md). The main goal is to let people compose by playing with images, without requiring them to understand scales, measures, synthesis, or music production tools.

## Product Principles

- Keep the core loop simple: choose photos, reorder them, press play.
- Treat every photo as a reusable musical object.
- Preserve deterministic generation: the same photo should produce the same musical result.
- Avoid DAW-style complexity in the initial product.
- Prefer expressive macro controls over detailed music editing.

## Current Prototype

The current app can:

- Capture a photo with the camera or choose one from the photo library.
- Normalize the image and generate a stable fingerprint.
- Convert the image into a low-resolution 4-tone, 2-bit-style cover.
- Analyze image color properties such as hue, saturation, luminance, hue variance, and edge density.
- Generate a 16-step by 8-row note grid from the processed image.
- Derive musical parameters from image features.
- Generate a short pedal name and one-sentence description using Apple Foundation Models.
- Play the result through an `AVAudioEngine`-based synth.
- Switch between reverb and distortion.
- Adjust effect intensity.
- Save and reload the latest pedal locally.
- Expose App Intents shortcuts for creating a pedal and playing the latest pedal.

## Technical Stack

- Platform: iOS
- Language: Swift
- UI: SwiftUI
- Camera and photo input: UIKit camera interop and PhotosUI
- Image analysis: Vision and VisionKit
- On-device text generation: Apple Foundation Models
- Audio: AVFoundation and `AVAudioEngine`
- Persistence: local Application Support files
- Shortcuts: App Intents
- Tests: Swift Testing
- Project: `snap-battle.xcodeproj`
- Main target: `snap-battle`
- Bundle identifier: `PedroKosciuk.snap-battle`
- Deployment target: iOS 26.5

## Generation Pipeline

1. The user captures or imports a photo.
2. `ImageInputPreparer` normalizes the image and prepares input data.
3. `RetroImageProcessor` creates the 2-bit-style cover image.
4. `PhotoColorAnalyzer` extracts visual features used by the music generator.
5. `ImageSequenceGenerator` maps image data into a deterministic note grid.
6. Vision and VisionKit provide visual metadata and subject extraction where available.
7. `FoundationModelsPedalGenerator` generates the pedal name and description.
8. `PhotoPedalPipeline` combines image, music, metadata, and effect choices into a pedal.
9. `PedalStore` persists the latest generated pedal locally.
10. `PhotoPedalSynth` plays the generated sequence.

## Music Generation

The prototype currently derives musical identity from visual features:

- Hue influences the root pitch class.
- Saturation and hue variance influence the scale profile.
- Luminance influences BPM and sound profile.
- Edge density influences rhythmic complexity.
- The processed image influences note placement and density.

The roadmap expands this into two layers:

- Meaningful musical identity: perceptible sound choices derived from image features.
- Deterministic micro-variations: stable small variations derived from an image hash.

Future generated pedals should store a `generatorVersion` so saved results do not change when the generation algorithm evolves.

## Data Model

The roadmap defines a persistent `Pedal` entity with:

- identifier;
- name;
- description;
- creation date;
- original image or local image reference;
- processed 2-bit image;
- note sequence;
- harmonic profile;
- root note;
- BPM;
- synth parameters;
- selected effect;
- effect parameters;
- generator version.

The current implementation persists only the latest pedal as local JSON and PNG files. A full gallery is planned next.

## Important Files

- App entry: `snap-battle/snap_battleApp.swift`
- Capture UI: `snap-battle/Features/Capture/`
- Pedal result UI: `snap-battle/Features/Pedal/PedalResultView.swift`
- Pedal domain model: `snap-battle/Domain/Pedal/Pedal.swift`
- Pedal pipeline: `snap-battle/Services/Pedal/PhotoPedalPipeline.swift`
- Color analysis: `snap-battle/Services/Pedal/PhotoColorAnalyzer.swift`
- Sequence generation: `snap-battle/Services/Pedal/ImageSequenceGenerator.swift`
- 2-bit cover processing: `snap-battle/Services/ImageProcessing/RetroImageProcessor.swift`
- Audio playback: `snap-battle/Services/Audio/PhotoPedalSynth.swift`
- Local persistence: `snap-battle/Services/Persistence/PedalStore.swift`
- App Intents: `snap-battle/Intents/PhotoPedalIntents.swift`

## Requirements

To run the full prototype on device:

- Xcode 26.5 or later.
- iOS 26.5 or later.
- A physical iPhone for camera, VisionKit, audio, and Apple Intelligence validation.
- Apple Intelligence enabled and a supported locale for Foundation Models naming.

If Foundation Models is unavailable, pedal naming cannot complete because the current generator requires `SystemLanguageModel.default.availability == .available` and current-locale support.

## Roadmap Summary

See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the source of truth.

Near-term priorities:

1. Improve musical variety.
2. Version and persist generated music recipes.
3. Build a real pedal gallery.
4. Add individual boards made from ordered pedals.
5. Add macro controls for effects such as Space, Drive, and Tone.
6. Add haptics and richer sensory feedback.
7. Add safe board sharing and import.

## Initial Non-Goals

Photo Pedal should not become a simplified DAW in the initial scope. Avoid adding:

- parallel tracks;
- piano roll editing;
- manual note editing;
- automation lanes;
- editable fades;
- individual duration controls;
- simultaneous playback of multiple independent pedals.

## Documentation

- [`docs/ROADMAP.md`](docs/ROADMAP.md): current product roadmap and source of truth.

Older documentation about creatures, combat, balancing, and the previous Snap Battle game direction has been removed to keep the repository aligned with Photo Pedal.
