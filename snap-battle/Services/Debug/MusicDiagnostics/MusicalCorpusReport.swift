#if DEBUG
import Foundation

/// Per-category rollup of a `MusicalCorpusReport`.
///
/// The aggregated values are computed only from the `runs` whose
/// `category` matches the report's category. This keeps the global and
/// per-category rollups consistent (the sum of per-category histograms
/// matches the global histogram modulo ordering).
struct MusicalCategoryReport: Codable, Equatable, Sendable {
    let category: String
    let runCount: Int
    let rootHistogram: [Int]                 // 12 bins
    let pitchClassHistogram: [Int]           // 12 bins
    let scaleHistogram: [String: Int]
    let pitchClassEntropy: Double            // global over the category
    let meanUniquePitchClassesPerSequence: Double
    let meanMaximumPitchClassShare: Double
    let meanIntervalSemitones: Double
    let meanNoteDensity: Double
    let meanRestDensity: Double
    let meanMultiNoteStepShare: Double
    let maximumObservedJumpSemitones: Int
}

/// Aggregated diagnostics for a baseline run over a corpus.
///
/// `generatedAt` is intentionally excluded from deterministic equality:
/// callers that need stable, byte-for-byte comparison should use
/// `normalized` (which replaces `generatedAt` with an empty string).
struct MusicalCorpusReport: Codable, Equatable, Sendable {
    /// Schema version of the report. Bump only on breaking changes.
    let reportVersion: Int
    /// Free-form timestamp string. Excluded from `normalized`.
    let generatedAt: String
    /// Identifier of the corpus that produced this report.
    let corpusIdentifier: String
    /// Algorithm version observed in every run.
    let algorithmVersion: Int
    /// Number of runs aggregated.
    let corpusSize: Int
    /// Per-category counts.
    let categoryCounts: [String: Int]

    // Global histograms
    let rootHistogram: [Int]                 // 12 bins
    let pitchClassHistogram: [Int]           // 12 bins
    let scaleHistogram: [String: Int]
    let bpmHistogram: [String: Int]          // bucketed by 10 BPM

    // Global metrics
    let globalPitchClassEntropy: Double
    let meanUniquePitchClassesPerSequence: Double
    let meanMaximumPitchClassShare: Double
    let meanIntervalSemitones: Double
    let maximumObservedJumpSemitones: Int
    let meanNoteDensity: Double
    let meanRestDensity: Double
    let meanMultiNoteStepShare: Double
    let meanSequenceGenerationDurationMilliseconds: Double
    let meanDiagnosticsDurationMilliseconds: Double
    let meanTotalRunDurationMilliseconds: Double

    // Per-category rollups (keys are sorted on construction)
    let categoryReports: [MusicalCategoryReport]

    // All individual runs (already sorted by identifier on construction)
    let runs: [MusicalRunDiagnostics]

    /// A copy of this report with `generatedAt` set to an empty string.
    /// Used for deterministic equality in tests.
    var normalized: MusicalCorpusReport {
        MusicalCorpusReport(
            reportVersion: reportVersion,
            generatedAt: "",
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
            meanSequenceGenerationDurationMilliseconds: meanSequenceGenerationDurationMilliseconds,
            meanDiagnosticsDurationMilliseconds: meanDiagnosticsDurationMilliseconds,
            meanTotalRunDurationMilliseconds: meanTotalRunDurationMilliseconds,
            categoryReports: categoryReports,
            runs: runs
        )
    }
}
#endif
