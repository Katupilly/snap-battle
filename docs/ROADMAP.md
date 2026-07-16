# Photo Pedal Roadmap

## Product Vision

Photo Pedal transforms images into small, collectible musical objects.

Each photo generates:

* a processed 2-bit cover image;
* a deterministic musical recipe;
* a note sequence;
* an effect and its parameters;
* a generated name and description;
* a reusable object that can be saved, reordered, and shared.

The goal is not to create a simplified DAW. The product should allow anyone to compose music by playing with images, without needing to understand scales, measures, synthesis, or music production.

---

# Phase 0 — Improve Musical Variety

**Priority: Highest**
**Complexity: Medium**

## Current Problem

The current system selects:

* one of 12 root notes based on hue;
* either a major or minor pentatonic scale based on saturation;
* BPM based on luminance.

This creates only 24 primary harmonic combinations. Even when rhythmic grids differ, multiple photos may still produce sequences with a similar musical character.

## Recommended Approach

Separate music generation into two layers.

### 1. Meaningful Musical Identity

Visual characteristics should select attributes that are clearly perceivable in the final sound:

* **Hue:** root note.
* **Saturation:** major, minor, or ambiguous tonal tendency.
* **Luminance:** octave range and BPM.
* **Contrast:** note density and harmonic tension.
* **Image temperature:** brighter or darker tonal profile.
* **Vertical distribution:** register and pitch range.
* **Edge density:** rhythmic complexity.

### 2. Deterministic Micro-Variations

A stable hash derived from the image can select smaller variations without changing its core identity:

* sequence rotation;
* starting octave;
* melodic direction;
* placement of rests;
* note duration variation;
* variation in the final four steps;
* velocity curve.

The same photo must always generate the same result.

## Suggested Harmonic Profiles

Instead of using only major and minor, use a small, curated collection of scales:

* Major Pentatonic: `[0, 2, 4, 7, 9]`
* Minor Pentatonic: `[0, 3, 5, 7, 10]`
* Suspended: `[0, 2, 5, 7, 10]`
* Major Blues: `[0, 2, 3, 4, 7, 9]`
* Minor Blues: `[0, 3, 5, 6, 7, 10]`
* Dark Pentatonic: `[0, 1, 5, 7, 10]`

These profiles should be treated as part of the app’s musical identity, not as a technical list of scales exposed to the user.

## Safety Rules

* Limit the number of simultaneous notes.
* Guarantee some rests in overly dense sequences.
* Avoid excessive octave jumps.
* Normalize velocity so that some images do not become nearly silent.
* Save the generated result instead of recalculating it every time.
* Store a `generatorVersion` so future updates do not change previously created pedals.

## Completion Criteria

* The same image always generates the exact same sequence.
* Existing saved pedals do not change after algorithm updates.
* Different image categories produce noticeably different musical results.
* No single harmonic profile dominates a varied sample of photos.
* Every sequence remains musically usable without manual editing.

---

# Phase 1 — Data Model and Gallery

**Priority: Highest**
**Complexity: Medium**

Before building pedalboards, the app needs persistent and reusable pedals.

## `Pedal` Entity

Each pedal should store:

* identifier;
* name;
* description;
* creation date;
* original image or local image reference;
* processed 2-bit image;
* note sequence;
* harmonic profile;
* root note;
* BPM;
* synth parameters;
* selected effect;
* effect parameters;
* generator version.

## Gallery

The gallery should allow users to:

* browse saved pedals;
* play a pedal directly;
* open pedal details;
* rename a pedal;
* delete a pedal;
* create a new pedal;
* import an edited image from the photo library;
* select a pedal and add it to a board.

## Initial Gallery Scope

Do not include yet:

* folders;
* tags;
* advanced search;
* cloud synchronization;
* social feeds;
* destructive image editing.

---

# Phase 2 — Individual Pedalboard

**Priority: High**
**Complexity: High**

This is the main evolution of the product.

## Mental Model

The user creates a composition by placing photos into a sequence.

The interface should include:

* a horizontal sequence;
* photo cards;
* drag and drop reordering;
* a playback position indicator;
* a large play and pause control;
* loop mode;
* an action to add another pedal;
* an action to remove a pedal;
* audio, visual, and haptic feedback while reordering.

## Core Simplicity Rule

The board should control global timing.

Each pedal keeps:

* its notes;
* its scale;
* its sound texture;
* its effect.

However, all pedals should be played using:

* the same pulse;
* a predictable duration;
* quantized entry points;
* synchronized transitions.

For the first version, each photo can occupy exactly **one measure**. Changing the order of the photos immediately changes the composition without introducing a full timeline editor.

## Initial Controls

Keep only:

* play and pause;
* loop;
* reorder;
* add;
* remove;
* optional global BPM.

Avoid initially:

* parallel tracks;
* automation;
* editable fades;
* piano roll;
* manual note editing;
* individual duration controls;
* simultaneous playback of multiple pedals.

## Naming Decision

Technically, this object is closer to a sequence of patches than a traditional pedalboard, because each element generates sound rather than only processing an audio input.

The interface can still use **Board**, but alternatives worth testing include:

* Photo Board;
* Sound Chain;
* Loop;
* Sequence;
* Mix;
* Path.

---

# Phase 3 — Improve Pedals and Controls

**Priority: High**
**Complexity: Medium**

Each effect should expose one understandable primary control.

## Reverb

Suggested control:

* **Space**

Internally, this control can adjust:

* wet/dry mix;
* perceived room size;
* reverberation intensity.

## Distortion

Suggested control:

* **Drive**

Internally, this control can adjust:

* pre-gain;
* wet/dry mix;
* distortion intensity.

The user should not see technical parameter names such as `wetDryMix`, `preGain`, or internal preset types.

## Synth Control

If a third macro control is necessary:

* **Tone:** darker ↔ brighter.

Additional controls should only be added when they produce an obvious and enjoyable change in the result.

---

# Phase 4 — Haptics and Sensory Feedback

**Priority: High and Cross-Functional**
**Complexity: Low to Medium**

Haptics should be implemented while the flows are being built, not after the product is finished.

Recommended moments:

* photo capture;
* processing completion;
* playback start;
* sequence step changes;
* transition to a new pedal;
* snapping a photo into a new position;
* activating reverb or distortion;
* reaching the minimum or maximum value of a control;
* successful sharing.

Not every note should necessarily produce a strong vibration. More noticeable haptics should be reserved for structural events, such as changing photos or snapping a card into position.

---

# Phase 5 — Board Sharing

**Priority: Medium**
**Complexity: Medium**

Create a custom shareable format, for example:

`board-name.photopedal`

## Package Contents

* schema version;
* board metadata;
* pedal order;
* musical recipes;
* effect parameters;
* 2-bit images;
* thumbnails;
* original images only when strictly necessary.

Because the audio is deterministic, pre-rendered audio files do not need to be included. The receiving device can reconstruct the sound from the stored musical recipe.

## AirDrop

The board should be shareable through the system share sheet, including AirDrop when available.

## Import Rules

* Import the board as an independent copy.
* Never overwrite an existing board automatically.
* Validate the file format version.
* Preserve older pedals even when the current generator has changed.
* Display a preview before confirming the import.

---

# Phase 6 — Collaborative Sessions

**Priority: Medium to Low**
**Complexity: Very High**

This phase should only begin after the individual pedalboard is stable.

## First Version

Limit collaboration to two people.

Synchronized actions:

* add pedal;
* remove pedal;
* move pedal;
* play;
* pause;
* change BPM;
* update playback position.

Do not initially synchronize:

* image editing;
* Foundation Models generation;
* high-frequency continuous controls;
* simultaneous multi-selection.

## Interaction Architecture

To reduce conflict, the first implementation can use one person as the host:

* the host maintains the authoritative state;
* the guest sends operations;
* the host validates and redistributes the state;
* each operation has an identifier and timestamp;
* the board can be rebuilt from the operation sequence.

This is simpler than implementing a fully distributed editing model or CRDT.

## Recommended Technology

SharePlay and Group Activities are the most suitable starting point for synchronized collaborative sessions.

A purely local peer-to-peer implementation is also possible, but it would increase the amount of work required for discovery, connections, reconnections, conflict handling, and state consistency.

For the first collaborative version, SharePlay should be preferred.

---

# Phase 7 — Final Visual Design

**Priority: High, After Structural Validation**

Design work should not begin only after all development is complete.

## Recommended Order

### Before Implementing the New Flows

* information architecture;
* navigation map;
* wireframes;
* error states;
* empty states;
* drag and drop prototype;
* validation of the pedalboard mental model.

### After Behavior Is Validated

* visual language;
* component system;
* motion;
* 2-bit image treatment;
* effect representation;
* iconography;
* transitions;
* accessibility;
* dark mode;
* Reduce Motion;
* final SwiftUI implementation.

## Flows That Must Be Mapped

1. First capture.
2. Photo processing.
3. Effect selection and adjustment.
4. Saving a pedal.
5. Gallery.
6. Playing an individual pedal.
7. Creating a board.
8. Adding pedals.
9. Reordering pedals.
10. Sharing a board.
11. Importing a board.
12. Starting and ending a collaborative session.
13. Handling conflicts or disconnections.
14. Exporting a video.

---

# Phase 8 — Social Media Video Export

**Priority: Optional**
**Complexity: Medium**

The simplest implementation should generate a vertical video containing:

* one photo per musical section;
* duration synchronized with each pedal;
* simple transitions or hard cuts;
* the board’s generated music;
* no manual editing;
* no complex templates;
* no required direct Instagram integration.

## Initial Format

* 9:16 aspect ratio;
* centered image or adaptive image fill;
* photo changes synchronized with the music;
* rendered board audio;
* video saved locally or presented through the system share sheet.

## Out of Scope for the First Export Version

* templates;
* animated text;
* waveform visualization;
* manual duration editing;
* additional filters;
* manually selected transitions;
* automatic publishing.

---

# Recommended Implementation Order

## P0 — Foundations

1. Improve musical variation.
2. Create a versioned `MusicRecipe`.
3. Consolidate pedal persistence.
4. Implement the gallery.
5. Add basic haptics.

## P1 — Core Product Value

6. Implement the individual pedalboard.
7. Add drag and drop.
8. Add sequential playback and loop mode.
9. Improve effect controls.
10. Validate the main flows through prototypes.
11. Implement the main visual design.

## P2 — Distribution

12. Create a shareable file format.
13. Add AirDrop and system sharing.
14. Implement board import.

## P3 — Social Experience

15. Add collaborative sessions.
16. Synchronize board operations.
17. Handle disconnections and session recovery.

## P4 — Stretch Goal

18. Add offline audio rendering.
19. Generate vertical videos.
20. Export to Photos or the system share sheet.

---

# Main Product Risk

The main risk is not MIDI generation or sharing. It is the pedalboard becoming a limited and complicated music editor.

The experience should remain centered around three actions:

1. Choose photos.
2. Change their order.
3. Press play.

Every additional control must clearly justify its presence.
