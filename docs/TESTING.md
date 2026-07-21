# Testing

## Current Test Structure

The `DapTests` target uses Swift Testing and currently has 83 tests in 8 suites.

The current suite includes legacy game coverage plus focused Dap coverage for deterministic generation, progressive fallback-before-enrichment metadata, metadata-only store updates, metadata fallback through the `PedalMetadataGenerating` seam, collection persistence/migration, navigation state, audio lifecycle coordination, and App Intent routing where it is testable without framework/device invocation. Camera UI, audible playback, route changes, Siri/Shortcuts framework integration, and live Foundation Models behavior remain device-validation items.

Run the shared scheme against an installed simulator:

```sh
xcodebuild test -project "Dap.xcodeproj" -scheme "Dap" -destination 'platform=iOS Simulator,name=<installed simulator>'
```

## Test Matrix

| Area | Unit | Integration | Simulator | Physical Device |
| --- | ---: | ---: | ---: | ---: |
| Image processing | Partial | No | Yes | Optional |
| Deterministic generation | Partial | No | Yes | Optional |
| Persistence | Yes | Partial | Possible | Required before release |
| Audio graph | Partial | No | Possible | Required |
| Perceptual audio | No | No | No | Required |
| Camera | No | No | No | Required |
| Foundation Models metadata fallback | Yes, through seam | Partial | Possible | Required for live model behavior |
| App Intents | Partial routing | No | Possible | Required |
| Haptics | No | No | No | Planned feature |

The repository has no documented fixture-image set; do not add binary fixtures without an approved specification. Simulator builds can validate deterministic, persistence, fallback, and routing behavior, but cannot complete camera hardware, perceptual audio, route-change, Siri/Shortcuts, or live Foundation Models validation.
