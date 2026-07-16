# Image-To-Music Generation

## Current Contract

`PhotoPedalPipeline` uses `ImageInputPreparer`, `RetroImageProcessor`, `PhotoColorAnalyzer`, and `ImageSequenceGenerator`. Foundation Models output does not affect music.

## Inputs

`ImageInputPreparer` normalizes orientation and renders a 32 by 32 sRGB representation to calculate a SHA-256 fingerprint. The fingerprint is currently neither used by generation nor persisted. `RetroImageProcessor` creates an aspect-preserving, 160-pixel-wide four-tone cover using error diffusion. `PhotoColorAnalyzer` samples the prepared image at 64 by 64.

## Outputs

Generation creates a `PedalSequence`: 16 steps, 8 rows, note events with MIDI pitch and velocity, `PedalHarmony`, and `PedalSoundProfile`. Each step is later rendered as a sixteenth note by the synth.

## Current Feature Mapping

| Image feature | Current musical result |
| --- | --- |
| Mean hue | Root pitch class: `floor(hue / 360 * 12)`, clamped 0...11 |
| Mean luminance | BPM: rounded 70...140; reverb preset/mix |
| Hue variance | Whole tone when over 70 degrees; Dorian from 30 through 70 degrees |
| Saturation with low hue variance | Major pentatonic at or above 0.45; otherwise minor pentatonic |
| Four-tone cover levels | Nonzero cells become notes; level controls velocity from 1/3 through 1 |
| Significant palette-tone count | Octave range: 1, 1.5, or 2 |
| Hue | Square waveform for 90 through under 300 degrees; triangle otherwise |
| Edge density | Gate length, distortion preset, and distortion mix |

## Determinism

Equivalent prepared pixels run through the same code produce the same sequence. Orientation normalization is performed; the pipeline uses no date, locale, random source, Vision result, or Foundation Models result in the musical calculation. Cross-device image-rendering equivalence and end-to-end regression coverage are unverified.

The full `PhotoPedal` is not deterministic because it includes a new UUID, timestamp, and generated metadata. No `generatorVersion` is stored; this is a high-priority gap.

## Edge Cases

Transparent pixels are excluded from color weighting; a fully transparent image produces zeroed color metrics. Hue-less pixels do not contribute to hue variance. Low/zero cover levels become rests. The current generator has no polyphony limit, guaranteed-rest rule, or explicit empty-sequence policy beyond the generated grid.

## Planned Variation

The roadmap proposes curated additional harmonic profiles, contrast-based density, vertical distribution, edge-based rhythm, and stable hash-based micro-variations. These are planned V2 behavior, not current behavior. See [music-generation-v2](../specs/current/music-generation-v2.md).
