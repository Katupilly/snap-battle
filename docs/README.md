# Snap Battle Documentation

## Index

- [Project Vision](#project-vision)
- [Goal](#goal)
- [Current Stack](#current-stack)
- [Apple Technologies](#apple-technologies)
- [General Architecture](#general-architecture)
- [Current PoC Status](#current-poc-status)
- [Documentation Map](#documentation-map)

## Project Vision

Snap Battle is a creature discovery game where real-world photos become original collectible creatures. The current direction prioritizes wonder, discovery, creativity, collection, and personal attachment before combat depth.

## Goal

The project should prove that an on-device Apple stack can transform an image into a structured creature identity through a reliable pipeline:

1. Prepare a user-provided image.
2. Extract or isolate the main subject when available.
3. Read visual metadata with Vision.
4. Use Foundation Models for creative creature identity.
5. Validate the generated draft.
6. Calculate game stats deterministically.
7. Present a complete creature result.

## Current Stack

| Area | Current Choice | Status |
| --- | --- | --- |
| App platform | iOS | Decided |
| UI | SwiftUI | Decided |
| Language | Swift | Decided |
| Tests | Swift Testing | Decided |
| AI runtime | Apple Foundation Models | Decided |
| Image analysis | Vision and VisionKit | Decided |
| Backend | None | Decided for PoC |

## Apple Technologies

- SwiftUI for the app interface.
- UIKit interop for camera capture and image preparation.
- Vision for image classification.
- VisionKit for subject extraction.
- Foundation Models for on-device structured creature generation.
- CryptoKit for stable image fingerprinting.
- OSLog for pipeline diagnostics.

## General Architecture

The current architecture is a small pipeline-centered SwiftUI app:

- `Features` contains capture, generation, and result UI.
- `Services` contains image preparation, Vision, Foundation Models, game rules, and pipeline orchestration.
- `Domain` contains creature, observation, stat, enum, and analysis models.
- `Supporting` contains errors and diagnostics.
- `snap-battleTests` contains deterministic and pipeline safety tests.

## Current PoC Status

Status: Active PoC.

Completed at a prototype level:

- Camera/photo input flow.
- Image normalization and fingerprinting.
- Subject extraction with fallback to the original image.
- Vision labels and heuristic material inference.
- Foundation Models creature draft generation.
- Draft validation.
- Deterministic stat calculation.
- Basic result view and diagnostics.
- Unit tests for determinism, budget limits, role identity, material modifiers, cancellation, and model errors.

Not yet implemented:

- Persistent collection.
- Creature history.
- Favorites.
- Combat.
- Multiplayer.
- RealityKit placement.
- Trading, evolution, events, achievements, or cloud sync.

## Documentation Map

- [Roadmap](ROADMAP.md)
- [Game Design](GAME_DESIGN.md)
- [Creature Generation](CREATURE_GENERATION.md)
- [Balancing and Stats](BALANCING-STATS.md)
- [Combat](COMBAT.md)
- [Foundation Models](FOUNDATION_MODELS.md)
- [Technical Decisions](TECH_DECISIONS.md)
- [Testing](TESTING.md)
