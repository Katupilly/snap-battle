#if DEBUG
import Foundation

/// Per-image diagnostic collected by the v1 baseline harness.
///
/// The struct is a value-type snapshot. It is calculated **after** the
/// sequence is produced and never participates in the v1 algorithm.
/// No field in this struct is persisted, sent to UI, or used by
/// `PhotoPedal`. Release builds do not include this type.
struct MusicalRunDiagnostics: Codable, Equatable, Sendable {
    /// Stable identifier for the source image (e.g. `portraitDay-001`).
    let imageIdentifier: String
    /// Primary category, or `nil` for ad-hoc runs that are not part of a corpus.
    let category: CorpusCategory?
    /// Observed algorithm version. Always `1` in Increment 1.
    let algorithmVersion: Int

    // Identity
    let rootPitchClass: Int
    let scale: String
    let bpm: Int

    // Counts
    let noteCount: Int
    let restStepCount: Int
    let singleNoteStepCount: Int
    let multiNoteStepCount: Int
    let uniqueMIDINotes: Int
    let uniquePitchClasses: Int

    // Distribution
    let pitchClassHistogram: [Int]            // 12 bins, sum == noteCount
    let pitchClassEntropy: Double             // bits, 0 when no notes
    let maximumPitchClassShare: Double        // 0...1

    // Intervals (extracted from the most-acute note per step)
    let meanIntervalSemitones: Double         // 0 when fewer than 2 notes
    let maximumJumpSemitones: Int             // 0 when fewer than 2 notes

    // Rhythm and density
    let durationHistogram: [String: Int]      // velocity buckets
    let noteDensity: Double                   // noteCount / 128
    let restDensity: Double                   // restStepCount / 16
    let multiNoteStepShare: Double            // multiNoteStepCount / max(1, stepsWithNotes)

    // Performance
    let sequenceGenerationDurationMilliseconds: Double
    let diagnosticsCalculationDurationMilliseconds: Double
    let totalRunDurationMilliseconds: Double
    let residentMemoryBytesBefore: UInt64?
    let residentMemoryBytesAfter: UInt64?
}
#endif
