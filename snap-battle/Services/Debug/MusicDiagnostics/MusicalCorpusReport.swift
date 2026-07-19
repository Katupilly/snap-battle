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
    /// Average of `meanNotesPerActiveStep` over the category.
    let meanNotesPerActiveStep: Double
    /// Average of `zeroIntervalTransitionShare` over the category.
    let meanZeroIntervalTransitionShare: Double
    /// Average share of active steps with exactly 1 note.
    let meanSingleVoiceStepShare: Double
    /// Average share of active steps with exactly 2 notes.
    let meanTwoVoiceStepShare: Double
    /// Average share of active steps with 3 or more notes.
    let meanThreeOrMoreVoiceStepShare: Double
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
    let meanNotesPerActiveStep: Double
    let meanZeroIntervalTransitionShare: Double
    let meanSingleVoiceStepShare: Double
    let meanTwoVoiceStepShare: Double
    let meanThreeOrMoreVoiceStepShare: Double
    let meanSequenceGenerationDurationMilliseconds: Double
    let meanDiagnosticsDurationMilliseconds: Double
    let meanTotalRunDurationMilliseconds: Double

    // Memory deltas. Signed because `after - before` can be negative.
    // `nil` when no run produced a valid sample pair.
    let meanResidentMemoryDeltaBytes: Int64?
    let maximumResidentMemoryDeltaBytes: Int64?
    let minimumResidentMemoryDeltaBytes: Int64?
    let runsWithMemorySamples: Int

    // Per-category rollups (keys are sorted on construction)
    let categoryReports: [MusicalCategoryReport]

    // All individual runs (already sorted by identifier on construction)
    let runs: [MusicalRunDiagnostics]

    /// A copy of this report with `generatedAt` set to an empty string.
    /// Used for deterministic equality in tests and for the versioned
    /// audit asset (Strategy A: drop volatile fields from the
    /// committed baseline).
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
            meanNotesPerActiveStep: meanNotesPerActiveStep,
            meanZeroIntervalTransitionShare: meanZeroIntervalTransitionShare,
            meanSingleVoiceStepShare: meanSingleVoiceStepShare,
            meanTwoVoiceStepShare: meanTwoVoiceStepShare,
            meanThreeOrMoreVoiceStepShare: meanThreeOrMoreVoiceStepShare,
            meanSequenceGenerationDurationMilliseconds: meanSequenceGenerationDurationMilliseconds,
            meanDiagnosticsDurationMilliseconds: meanDiagnosticsDurationMilliseconds,
            meanTotalRunDurationMilliseconds: meanTotalRunDurationMilliseconds,
            meanResidentMemoryDeltaBytes: meanResidentMemoryDeltaBytes,
            maximumResidentMemoryDeltaBytes: maximumResidentMemoryDeltaBytes,
            minimumResidentMemoryDeltaBytes: minimumResidentMemoryDeltaBytes,
            runsWithMemorySamples: runsWithMemorySamples,
            categoryReports: categoryReports,
            runs: runs
        )
    }
}
#endif
