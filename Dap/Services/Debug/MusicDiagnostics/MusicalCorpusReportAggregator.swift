#if DEBUG
import Foundation

/// Aggregates a set of `MusicalRunDiagnostics` into a `MusicalCorpusReport`.
///
/// The aggregator is pure: same input → same output (modulo
/// `generatedAt`, which is set by the caller).
///
/// All dictionaries and arrays are sorted before export so that JSON
/// output is stable for the same input.
enum MusicalCorpusReportAggregator {

    /// Aggregate runs into a report.
    ///
    /// - Parameters:
    ///   - runs: the per-image diagnostics. May be empty.
    ///   - corpusIdentifier: stable identifier (e.g. `procedural-v1`).
    ///   - generatedAt: free-form timestamp. The caller should pass
    ///     the same value across reruns to keep reports comparable.
    ///   - reportVersion: schema version.
    ///   - algorithmVersion: observed algorithm version in every run.
    static func aggregate(
        runs: [MusicalRunDiagnostics],
        corpusIdentifier: String,
        generatedAt: String,
        reportVersion: Int = 1,
        algorithmVersion: Int = 1
    ) -> MusicalCorpusReport {
        let corpusSize = runs.count

        // Category counts (sorted keys for stability)
        var categoryCounts: [String: Int] = [:]
        for run in runs {
            let key = run.category?.rawValue ?? "uncategorized"
            categoryCounts[key, default: 0] += 1
        }
        categoryCounts = sorted(categoryCounts)

        // Global histograms
        let rootHistogram = sumHistogram(runs: runs, key: \.rootPitchClass, bins: 12)
        let pitchClassHistogram = sumFlatHistogram(runs: runs, key: \.pitchClassHistogram, bins: 12)
        let scaleHistogram = sorted(countBy(runs: runs, keyPath: \.scale))
        let bpmHistogram = sorted(bpmBuckets(runs: runs))

        // Global metrics
        let globalPitchClassEntropy = MusicalDiagnosticsCalculator.entropy(
            from: pitchClassHistogram,
            total: pitchClassHistogram.reduce(0, +)
        )
        let meanUniquePitchClassesPerSequence = mean(runs: runs, keyPath: \.uniquePitchClasses)
        let meanMaximumPitchClassShare = mean(runs: runs, keyPath: \.maximumPitchClassShare)
        let meanIntervalSemitones = mean(runs: runs, keyPath: \.meanIntervalSemitones)
        let maximumObservedJumpSemitones = runs.map(\.maximumJumpSemitones).max() ?? 0
        let meanNoteDensity = mean(runs: runs, keyPath: \.noteDensity)
        let meanRestDensity = mean(runs: runs, keyPath: \.restDensity)
        let meanMultiNoteStepShare = mean(runs: runs, keyPath: \.multiNoteStepShare)
        let meanNotesPerActiveStep = mean(runs: runs, keyPath: \.meanNotesPerActiveStep)
        let meanZeroIntervalTransitionShare = mean(runs: runs, keyPath: \.zeroIntervalTransitionShare)
        let meanSingleVoiceStepShare = meanStepVoiceShare(runs: runs, keyPath: \.singleVoiceStepCount)
        let meanTwoVoiceStepShare = meanStepVoiceShare(runs: runs, keyPath: \.twoVoiceStepCount)
        let meanThreeOrMoreVoiceStepShare = meanStepVoiceShare(runs: runs, keyPath: \.threeOrMoreVoiceStepCount)
        let meanSeqMs = mean(runs: runs, keyPath: \.sequenceGenerationDurationMilliseconds)
        let meanDiagMs = mean(runs: runs, keyPath: \.diagnosticsCalculationDurationMilliseconds)
        let meanTotalMs = mean(runs: runs, keyPath: \.totalRunDurationMilliseconds)

        // Memory deltas. The delta is signed because the kernel may
        // reclaim pages between samples. We expose nil when no run
        // produced a valid pair so the consumer can distinguish
        // "no signal" from "zero delta".
        let memorySummary = aggregateResidentMemoryDelta(runs: runs)

        // Per-category rollups (sorted by category name)
        let categoryReports = buildCategoryReports(runs: runs)

        // Sort runs by identifier for stable output
        let sortedRuns = runs.sorted { $0.imageIdentifier < $1.imageIdentifier }

        return MusicalCorpusReport(
            reportVersion: reportVersion,
            generatedAt: generatedAt,
            corpusIdentifier: corpusIdentifier,
            algorithmVersion: algorithmVersion,
            corpusSize: corpusSize,
            categoryCounts: categoryCounts,
            rootHistogram: rootHistogram,
            pitchClassHistogram: pitchClassHistogram,
            scaleHistogram: scaleHistogram,
            bpmHistogram: bpmHistogram,
            globalPitchClassEntropy: globalPitchClassEntropy,
            meanUniquePitchClassesPerSequence: meanUniquePitchClassesPerSequence,
            meanMaximumPitchClassShare: meanMaximumPitchClassShare,
            meanIntervalSemitones: meanIntervalSemitones,
            maximumObservedJumpSemitones: maximumObservedJumpSemitones,
            meanNoteDensity: meanNoteDensity,
            meanRestDensity: meanRestDensity,
            meanMultiNoteStepShare: meanMultiNoteStepShare,
            meanNotesPerActiveStep: meanNotesPerActiveStep,
            meanZeroIntervalTransitionShare: meanZeroIntervalTransitionShare,
            meanSingleVoiceStepShare: meanSingleVoiceStepShare,
            meanTwoVoiceStepShare: meanTwoVoiceStepShare,
            meanThreeOrMoreVoiceStepShare: meanThreeOrMoreVoiceStepShare,
            meanSequenceGenerationDurationMilliseconds: meanSeqMs,
            meanDiagnosticsDurationMilliseconds: meanDiagMs,
            meanTotalRunDurationMilliseconds: meanTotalMs,
            meanResidentMemoryDeltaBytes: memorySummary.mean,
            maximumResidentMemoryDeltaBytes: memorySummary.max,
            minimumResidentMemoryDeltaBytes: memorySummary.min,
            runsWithMemorySamples: memorySummary.count,
            categoryReports: categoryReports,
            runs: sortedRuns
        )
    }

    // MARK: - Helpers

    private static func sumHistogram(runs: [MusicalRunDiagnostics], key keyPath: KeyPath<MusicalRunDiagnostics, Int>, bins: Int) -> [Int] {
        var bins_ = Array(repeating: 0, count: bins)
        for run in runs {
            let value = run[keyPath: keyPath]
            guard (0..<bins).contains(value) else { continue }
            bins_[value] += 1
        }
        return bins_
    }

    private static func sumFlatHistogram(runs: [MusicalRunDiagnostics], key keyPath: KeyPath<MusicalRunDiagnostics, [Int]>, bins: Int) -> [Int] {
        var bins_ = Array(repeating: 0, count: bins)
        for run in runs {
            let histogram = run[keyPath: keyPath]
            guard histogram.count == bins else { continue }
            for index in 0..<bins {
                bins_[index] += histogram[index]
            }
        }
        return bins_
    }

    private static func countBy(runs: [MusicalRunDiagnostics], keyPath: KeyPath<MusicalRunDiagnostics, String>) -> [String: Int] {
        var result: [String: Int] = [:]
        for run in runs {
            let key = run[keyPath: keyPath]
            result[key, default: 0] += 1
        }
        return result
    }

    private static func bpmBuckets(runs: [MusicalRunDiagnostics]) -> [String: Int] {
        var result: [String: Int] = [:]
        for run in runs {
            let bucket = bpmBucket(run.bpm)
            result[bucket, default: 0] += 1
        }
        return result
    }

    private static func bpmBucket(_ bpm: Int) -> String {
        let lower = (bpm / 10) * 10
        return "\(lower)-\(lower + 9)"
    }

    private static func mean(runs: [MusicalRunDiagnostics], keyPath: KeyPath<MusicalRunDiagnostics, Double>) -> Double {
        guard !runs.isEmpty else { return 0 }
        let total = runs.reduce(0.0) { $0 + $1[keyPath: keyPath] }
        return total / Double(runs.count)
    }

    private static func mean(runs: [MusicalRunDiagnostics], keyPath: KeyPath<MusicalRunDiagnostics, Int>) -> Double {
        guard !runs.isEmpty else { return 0 }
        let total = runs.reduce(0) { $0 + $1[keyPath: keyPath] }
        return Double(total) / Double(runs.count)
    }

    /// Average of a per-step voice count over the active steps in a run.
    /// When the run has no active steps the per-run share is `0`, so a
    /// corpus with any all-rests runs still produces a finite mean.
    private static func meanStepVoiceShare(runs: [MusicalRunDiagnostics], keyPath: KeyPath<MusicalRunDiagnostics, Int>) -> Double {
        guard !runs.isEmpty else { return 0 }
        let shares = runs.map { run -> Double in
            let active = run.activeStepCount
            guard active > 0 else { return 0 }
            return Double(run[keyPath: keyPath]) / Double(active)
        }
        return shares.reduce(0, +) / Double(runs.count)
    }

    private static func sorted(_ dict: [String: Int]) -> [String: Int] {
        let keys = dict.keys.sorted()
        var result: [String: Int] = [:]
        for key in keys { result[key] = dict[key] }
        return result
    }

    private struct MemorySummary: Equatable {
        var mean: Int64?
        var max: Int64?
        var min: Int64?
        var count: Int
    }

    private static func aggregateResidentMemoryDelta(runs: [MusicalRunDiagnostics]) -> MemorySummary {
        // The delta uses Int64 because `after - before` can be negative
        // (the kernel may reclaim pages between samples). The signed
        // type also prevents wrap-around on platforms where resident
        // size approaches UInt64.max in pathological cases.
        var deltas: [Int64] = []
        deltas.reserveCapacity(runs.count)
        for run in runs {
            guard let before = run.residentMemoryBytesBefore,
                  let after = run.residentMemoryBytesAfter else { continue }
            let delta = Int64(after) &- Int64(before)
            deltas.append(delta)
        }
        guard !deltas.isEmpty else {
            return MemorySummary(mean: nil, max: nil, min: nil, count: 0)
        }
        let total = deltas.reduce(Int64(0), +)
        let count = Int64(deltas.count)
        let meanValue = total / count
        return MemorySummary(
            mean: meanValue,
            max: deltas.max(),
            min: deltas.min(),
            count: deltas.count
        )
    }

    private static func buildCategoryReports(runs: [MusicalRunDiagnostics]) -> [MusicalCategoryReport] {
        let grouped = Dictionary(grouping: runs) { run -> String in
            run.category?.rawValue ?? "uncategorized"
        }
        let sortedKeys = grouped.keys.sorted()
        return sortedKeys.map { key in
            let subset = grouped[key] ?? []
            let rootHistogram = sumHistogram(runs: subset, key: \.rootPitchClass, bins: 12)
            let pitchClassHistogram = sumFlatHistogram(runs: subset, key: \.pitchClassHistogram, bins: 12)
            let scaleHistogram = sorted(countBy(runs: subset, keyPath: \.scale))
            let entropy = MusicalDiagnosticsCalculator.entropy(
                from: pitchClassHistogram,
                total: pitchClassHistogram.reduce(0, +)
            )
            return MusicalCategoryReport(
                category: key,
                runCount: subset.count,
                rootHistogram: rootHistogram,
                pitchClassHistogram: pitchClassHistogram,
                scaleHistogram: scaleHistogram,
                pitchClassEntropy: entropy,
                meanUniquePitchClassesPerSequence: mean(runs: subset, keyPath: \.uniquePitchClasses),
                meanMaximumPitchClassShare: mean(runs: subset, keyPath: \.maximumPitchClassShare),
                meanIntervalSemitones: mean(runs: subset, keyPath: \.meanIntervalSemitones),
                meanNoteDensity: mean(runs: subset, keyPath: \.noteDensity),
                meanRestDensity: mean(runs: subset, keyPath: \.restDensity),
                meanMultiNoteStepShare: mean(runs: subset, keyPath: \.multiNoteStepShare),
                meanNotesPerActiveStep: mean(runs: subset, keyPath: \.meanNotesPerActiveStep),
                meanZeroIntervalTransitionShare: mean(runs: subset, keyPath: \.zeroIntervalTransitionShare),
                meanSingleVoiceStepShare: meanStepVoiceShare(runs: subset, keyPath: \.singleVoiceStepCount),
                meanTwoVoiceStepShare: meanStepVoiceShare(runs: subset, keyPath: \.twoVoiceStepCount),
                meanThreeOrMoreVoiceStepShare: meanStepVoiceShare(runs: subset, keyPath: \.threeOrMoreVoiceStepCount),
                maximumObservedJumpSemitones: subset.map(\.maximumJumpSemitones).max() ?? 0
            )
        }
    }
}
#endif
