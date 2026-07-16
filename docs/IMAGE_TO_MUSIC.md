# Image-To-Music Generation

## Current Contract

`PhotoPedalPipeline` uses `ImageInputPreparer`, `RetroImageProcessor`, `PhotoColorAnalyzer`, and `ImageSequenceGenerator`. Foundation Models output does not affect music.

## Inputs

`ImageInputPreparer` normalizes orientation and renders a 32 by 32 sRGB representation to calculate a SHA-256 fingerprint. The fingerprint is not consumed by generation, persisted, used for deduplication, used as a seed, used as a cache key, or used as a test contract. `RetroImageProcessor` creates an aspect-preserving, 160-pixel-wide four-tone cover using error diffusion. `PhotoColorAnalyzer` samples the prepared image at 64 by 64.

> The fingerprint currently has no confirmed product responsibility. Future use requires a separate approved spec. Possible future uses such as diagnostics, caching, deduplication, fixtures, or input identity are not approved decisions.

## Outputs

Generation creates a `PedalSequence`: 16 steps, 8 rows, note events with MIDI pitch and velocity, `PedalHarmony`, and `PedalSoundProfile`. Each step is later rendered as a sixteenth note by the synth.

## Current Feature Mapping

| Image feature | Current musical result |
| --- | --- |
| Mean hue | Root pitch class: `floor(hue / 360 * 12)`, clamped 0...11 |
| Mean luminance | BPM: rounded 70...140; reverb preset/mix |
| Hue variance | Whole tone when over 70 degrees; Dorian from 30 through 70 degrees |
| Saturation with low hue variance | Major pentatonic at or above 0.45; otherwise minor pentatonic |
| Four-tone cover levels | `level == 0` is a rest; levels `1...3` create notes with velocity from 1/3 through 1 |
| Significant palette-tone count | Octave range: 1, 1.5, or 2 |
| Hue | Square waveform for 90 through under 300 degrees; triangle otherwise |
| Edge density | Gate length, distortion preset, and distortion mix |

## Determinism Boundaries

### Musical Transformation Determinism

For the same normalized visual input, the same current algorithm, and the same derived analysis values, the transformation produces the same essential musical data: selected scale, note and rest placement, event order, BPM-derived rhythm, MIDI notes, velocities, root pitch class, and visual-analysis-derived sound-profile parameters. Orientation is normalized. The musical calculation does not consume date, locale, randomness, Vision results, or Foundation Models output.

Cross-device equivalence of image rendering and end-to-end deterministic regression coverage are not established.

### Not Guaranteed By This Contract

This contract does not include the `PhotoPedal` UUID, creation date, name, description, Foundation Models metadata, or temporary playback state. These values do not define musical identity and may vary between creations.

There is no `generatorVersion` in the current model. Compatibility between future algorithm versions is not guaranteed by current code.

## Edge Cases

Transparent pixels are excluded from color weighting; a fully transparent image produces zeroed color metrics. Hue-less pixels do not contribute to hue variance. Only cover level `0` is a rest; levels `1`, `2`, and `3` create notes. The current generator has no polyphony limit, guaranteed-rest rule, or explicit empty-sequence policy beyond the generated grid.

## Planned Variation

The roadmap proposes curated additional harmonic profiles, contrast-based density, vertical distribution, edge-based rhythm, and possible stable micro-variations. These are planned behavior, not current behavior. See the [Music Generation V2 draft](../specs/planned/music-generation-v2.md).
