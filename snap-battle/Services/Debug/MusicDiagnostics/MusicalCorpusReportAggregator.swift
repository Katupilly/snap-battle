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
        let meanSeqMs = mean(runs: runs, keyPath: \.sequenceGenerationDurationMilliseconds)
        let meanDiagMs = mean(runs: runs, keyPath: \.diagnosticsCalculationDurationMilliseconds)
        let meanTotalMs = mean(runs: runs, keyPath: \.totalRunDurationMilliseconds)

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
            meanSequenceGenerationDurationMilliseconds: meanSeqMs,
            meanDiagnosticsDurationMilliseconds: meanDiagMs,
            meanTotalRunDurationMilliseconds: meanTotalMs,
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

    private static func sorted(_ dict: [String: Int]) -> [String: Int] {
        let keys = dict.keys.sorted()
        var result: [String: Int] = [:]
        for key in keys { result[key] = dict[key] }
        return result
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
                maximumObservedJumpSemitones: subset.map(\.maximumJumpSemitones).max() ?? 0
            )
        }
    }
}
#endif
