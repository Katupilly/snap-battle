# Testing

## Current Test Structure

The `snap-battleTests` target uses Swift Testing and has 52 `@Test` methods. Files include `CreatureAuditTests.swift`, `BattleEngineTests.swift`, `TimingEvaluatorTests.swift`, `BattleViewModelTests.swift`, and `SimpleBattleAITests.swift`.

Most coverage is legacy game coverage. `CreatureAuditTests.swift` contains some pedal/image checks, but there are no dedicated tests for `PhotoPedalPipeline`, `PedalStore`, `PhotoPedalSynth`, camera UI, App Intents, or live Foundation Models.

Run the shared scheme against an installed simulator:

```sh
xcodebuild test -project "snap-battle.xcodeproj" -scheme "snap-battle" -destination 'platform=iOS Simulator,name=<installed simulator>'
```

## Test Matrix

| Area | Unit | Integration | Simulator | Physical Device |
| --- | ---: | ---: | ---: | ---: |
| Image processing | Partial | No | Yes | Optional |
| Deterministic generation | Partial | No | Yes | Optional |
| Persistence | No | No | Possible | Required before release |
| Audio graph | No | No | Possible | Required |
| Perceptual audio | No | No | No | Required |
| Camera | No | No | No | Required |
| Foundation Models | No | No | No | Required |
| App Intents | No | No | Possible | Required |
| Haptics | No | No | No | Planned feature |

Future generator work must add deterministic fixtures and regression assertions. The repository has no documented fixture-image set; do not add binary fixtures without an approved specification.
