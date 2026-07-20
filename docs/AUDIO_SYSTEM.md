# Audio System

## Current Implementation

`Services/Audio/PhotoPedalSynth.swift` owns an `AVAudioEngine` graph:

`AVAudioSourceNode -> AVAudioUnitReverb -> AVAudioUnitDistortion -> mainMixerNode`

It uses stereo 44.1 kHz output, duplicates a mono rendered sample into both channels, and renders the complete 16-step sequence into memory before playback. A step lasts `60 / BPM / 4`; the sequence duration is four beats.

`PedalWaveform.square` and `.triangle` use lookup tables. A fixed attack/decay/release envelope is applied, notes are summed, and output is hard-clamped to +/-0.92. Both effects remain in the graph; the selected one receives its saved wet/dry mix and the other receives zero.

## Session And Playback

`PhotoPedalSynth.play(_:)` stops existing playback, configures `AVAudioSession` with category `.playback` and mode `.default`, activates the session, applies the selected effect, prepares the rendered buffer, and starts the engine.

`PhotoPedalSynth` exposes a minimal stop-reason callback for coordinators. Requested stops are distinct from interruption and engine-failure stops, so explicit `stop()` calls do not look like unexpected playback failures.

`PedalboardPlaybackCoordinator` reuses this player path for sequential board playback. Because the synth does not emit a natural end-of-buffer completion, board progression uses the same sample-aligned duration formula as rendering: `samplesPerStep = max(1, Int(sampleRate * 60 / bpm / 4))`, `totalSamples = samplesPerStep * 16`, and `duration = totalSamples / sampleRate`. Rests, gate, and note count do not change total duration because the synth renders all 16 steps.

### Deterministic Musical Data

The persisted sequence and sound-profile values sent to the synth can be deterministic under the image-to-music contract.

### Playback Equivalence

Realtime playback should be musically equivalent for the same persisted musical data, but it is not documented as byte-for-byte identical. Device hardware, audio route, latency, interruptions, scheduling, and audio-session state can affect runtime behavior.

## Controls And Limits

The current UI selects reverb or distortion and adjusts the selected mix. It does not expose the planned Space, Drive, or Tone names. There is no pause/resume, seek, loop, tempo change during playback, polyphony cap, offline rendering, or export.

The implementation has no documented sample-rate negotiation or route-change policy. It observes interruptions and calls `stop()` when an interruption begins; automatic recovery is not implemented in the current codebase.

Route-change handling, pause/resume, lifecycle recovery, board UI integration, and offline rendering are **not implemented in the current codebase**.

## Validation Boundary

Pure sequence construction is unit-testable. AVAudioEngine graph behavior is integration-testable at best. Camera, audible output, route changes, Bluetooth, interruptions, and perceived latency are device-only checks. There are currently no dedicated Dap audio tests.
