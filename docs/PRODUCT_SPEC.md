# Product Specification

## Product Statement

Photo Pedal transforms photos into playable and collectible musical objects.

## Target User Experience

A person without music-production knowledge can capture or choose a photo, receive a 2-bit visual object, hear its generated sequence, choose reverb or distortion, adjust its intensity, and save/replay the latest result. Combining saved pedals into an ordered board is planned, not implemented.

## Product Principles

- Image first
- Playful before precise
- Deterministic but varied
- No music theory required
- Immediate feedback
- Few meaningful controls
- Generated musical results remain stable after saving
- Composition through ordering rather than detailed editing

## Current MVP

| Capability | Status | Notes |
| --- | --- | --- |
| Capture and photo-library input | Implemented | `CaptureView` and `CameraScreen` |
| 2-bit cover processing | Implemented | Four-tone retro output |
| Image-to-music sequence | Implemented | 16 steps by 8 rows |
| Reverb or distortion | Implemented | UI exposes a generic intensity slider |
| Foundation Models name/description | Implemented | Unavailable models currently fail creation |
| Save and replay | Partially implemented | Only the latest pedal is stored |
| Gallery and reusable collection | Planned | No gallery model or UI |
| Ordered board | Planned | No board model or playback |

## Non-Goals

Photo Pedal is not a DAW, professional synthesizer, multitrack editor, manual MIDI sequencer, social network, or cloud collaboration platform in the current MVP.

## Product Risks

- Different photos can still sound perceptually similar.
- The "pedal" metaphor differs from the underlying generated-sound behavior.
- Boards could become a complicated music editor.
- Generated names may feel decorative rather than meaningful.
