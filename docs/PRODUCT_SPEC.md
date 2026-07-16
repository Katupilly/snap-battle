# Product Specification

## Product Statement

Photo Pedal transforms photos into playable and collectible musical objects.

## Target User Experience

A person without music-production knowledge can capture or choose a photo, receive a 2-bit visual object, hear its generated sequence, choose reverb or distortion, adjust its intensity, and replay the latest result. Combining saved pedals into an ordered board is planned, not implemented.

## Product Principles

- Image first
- Playful before precise
- Deterministic but varied
- No music theory required
- Immediate feedback
- Few meaningful controls
- Generated musical results remain stable after saving
- Composition through ordering rather than detailed editing

## Current Implementation Status

### Implemented

- Photo-library input through `PedalCaptureView` and camera capture through `CameraScreen`.
- Four-tone processed cover generation and a 16-step by 8-row image-to-music sequence.
- Reverb or distortion selection with a generic intensity control.
- Foundation Models-generated name and description; unavailable models currently fail creation.

### Partially Implemented

- The app stores and reloads only the latest pedal. Processing saves it automatically; there is no separate user save action or collection of pedals.
- The latest pedal can be replayed, but it is not a persistent, reusable library item.

### Planned

- Generator versioning.
- Complete pedal persistence and a gallery.
- Board playback and ordering.
- Sharing, collaboration, and video export.

## Non-Goals

Photo Pedal is not a DAW, professional synthesizer, multitrack editor, manual MIDI sequencer, social network, or cloud collaboration platform in the current MVP.

## Product Risks

- Different photos can still sound perceptually similar.
- The "pedal" metaphor differs from the underlying generated-sound behavior.
- Boards could become a complicated music editor.
- Generated names may feel decorative rather than meaningful.
