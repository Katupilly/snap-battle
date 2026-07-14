# Testing

## Index

- [Purpose](#purpose)
- [Current Coverage](#current-coverage)
- [Pipeline Tests](#pipeline-tests)
- [Determinism](#determinism)
- [Foundation Models](#foundation-models)
- [Vision](#vision)
- [Device Testing](#device-testing)
- [Simulator Limitations](#simulator-limitations)
- [Known Limitations](#known-limitations)
- [Future Benchmarks](#future-benchmarks)
- [Open Questions](#open-questions)

## Purpose

Testing should protect the generation pipeline, deterministic game rules, model boundaries, and device-specific behavior.

## Current Coverage

Status: Implemented in the PoC.

| Area | Covered |
| --- | --- |
| Image fingerprint | Same pixels produce the same fingerprint across scale differences. |
| Stat determinism | Same inputs produce same stats. |
| Label ordering | Label order does not change stats. |
| Stat budget | Total matches the fixed budget. |
| Stat bounds | Minimum and maximum are respected. |
| Role identity | Each role prioritizes its expected stat. |
| Material modifier | Material can change stat distribution. |
| Cancellation | Pipeline cancellation is propagated. |
| Invalid model output | Invalid draft is rejected. |
| Model unavailable | Availability errors are propagated. |

## Pipeline Tests

Current pipeline tests use test doubles for:

- Subject extraction.
- Object analysis.
- Creature generation.

This allows the app to test orchestration, validation, cancellation, and error propagation without requiring live Vision or Foundation Models in unit tests.

## Determinism

Current deterministic guarantees:

- Image fingerprinting is stable for the same pixels.
- Stat calculation is stable for the same name, role, labels, and material.
- Label order does not affect stat output.
- Stat totals and bounds are enforced.

Not guaranteed:

- Foundation Models output identity may vary.
- Vision labels may vary by OS, device, model version, or image conditions.

## Foundation Models

Current test approach:

- Use a mock generator for success, invalid draft, delay, and model unavailable paths.
- Validate that numeric stats remain outside the model flow.

Needed later:

- Prompt quality evaluation set.
- Refusal and safety scenario samples.
- Locale and availability matrix.
- Prompt version regression tests.

## Vision

Current test approach:

- Vision behavior is mostly isolated behind protocol boundaries.
- Unit tests do not depend on live Vision classification.

Needed later:

- Device image set with expected broad observations.
- Subject extraction fallback coverage on real devices.
- Material heuristic tests with representative label sets.
- Low-confidence label handling.

## Device Testing

Device testing matters because:

- VisionKit subject extraction depends on device support.
- Foundation Models depends on Apple Intelligence availability.
- Model readiness can be temporary.
- Camera behavior cannot be fully represented by unit tests.
- Memory and performance are image-size dependent.

## Simulator Limitations

Known simulator limitations:

- Camera capture may not represent real capture behavior.
- Foundation Models and Apple Intelligence availability may not match target devices.
- VisionKit subject extraction support may differ from physical devices.
- Performance and memory measurements are not representative.

## Known Limitations

- No persisted fixture suite for real photos yet.
- No snapshot tests for result UI.
- No performance baseline for large images.
- No automated quality scoring for generated creature identity.
- No combat tests because combat is not implemented.

## Future Benchmarks

Status: Exploration.

| Benchmark | Purpose |
| --- | --- |
| Pipeline duration | Track latency by stage. |
| Memory use | Prevent image processing regressions. |
| Model availability | Track supported devices and locales. |
| Generation quality | Compare prompt versions. |
| Vision stability | Detect label changes across OS/device updates. |
| Collection scale | Test persistence once collection exists. |
| Combat simulation | Balance stats and abilities once combat exists. |

## Open Questions

- What real photo fixture set should define the quality bar?
- Should generated text be approved manually before becoming a regression fixture?
- How should nondeterministic model output be evaluated?
- Which devices are the minimum supported target?
- What pipeline latency is acceptable for a satisfying user experience?
