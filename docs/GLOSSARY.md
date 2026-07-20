# Glossary

## Pedal

A `PhotoPedal`: one generated musical record derived from a source image. Current storage retains only the latest record; it is not yet a collection of saved pedals.

## Music Recipe

The musical information used to reproduce playback. No type with this name exists yet; the current equivalent is `PedalSequence`, `PedalHarmony`, `PedalNote`, and `PedalSoundProfile`. Deterministic transformation of those values does not imply byte-identical realtime audio output.

## Board

A planned ordered sequence of pedals sharing playback timing. No board model exists.

## Effect

The selected `PedalEffect` and its saved mix: reverb or distortion.

## Synth Configuration

`PedalSoundProfile`: gate, octave range, waveform, presets, and effect mixes.

## Source Image

The camera-captured or imported image sent to preparation and analysis. It is not currently persisted.

## Processed Image

The four-tone, 2-bit-style cover produced by `RetroImageProcessor` and saved as PNG.

## Patch

Not a current domain type. The roadmap may use it descriptively for a sound-producing element; use Pedal in new product work.

## Deprecated Game Terms

Do not introduce Creature, Battle, Stats, Attack, Defense, Enemy, Signal, Overdrive, Noise Shield, or Tempo Shift into new Dap features. Some remain in compiled legacy code and tests.
