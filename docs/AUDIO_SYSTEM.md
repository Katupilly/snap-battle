# Audio System

## Current Implementation

`Services/Audio/PhotoPedalSynth.swift` owns an `AVAudioEngine` graph:

`AVAudioSourceNode -> AVAudioUnitReverb -> AVAudioUnitDistortion -> mainMixerNode`

It uses stereo 44.1 kHz output, duplicates a mono rendered sample into both channels, and renders the complete 16-step sequence into memory before playback. A step lasts `60 / BPM / 4`; the sequence duration is four beats.

`PedalWaveform.square` and `.triangle` use lookup tables. A fixed attack/decay/release envelope is applied, notes are summed, and output is hard-clamped to +/-0.92. Both effects remain in the graph; the selected one receives its saved wet/dry mix and the other receives zero.

## Controls And Limits

The current UI selects reverb or distortion and adjusts the selected mix. It does not expose the planned Space, Drive, or Tone names. There is no pause/resume, seek, loop, tempo change during playback, board playback, polyphony cap, offline rendering, or export.

The implementation does not establish an explicit `AVAudioSession` configuration, sample-rate negotiation policy, or route-change policy. Interruption handling calls `stop()`. Route-change recovery and lifecycle recovery require device validation before being documented as supported.

## Validation Boundary

Pure sequence construction is unit-testable. AVAudioEngine graph behavior is integration-testable at best. Camera, audible output, route changes, Bluetooth, interruptions, and perceived latency are device-only checks. There are currently no dedicated Photo Pedal audio tests.
