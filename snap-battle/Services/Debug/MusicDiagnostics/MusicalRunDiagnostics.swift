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
    /// Steps that contain at least one note. Equal to
    /// `PedalSequence.steps - restStepCount`.
    let activeStepCount: Int
    /// Average number of notes per active step.
    /// Returns `0` when there are no active steps.
    let meanNotesPerActiveStep: Double
    /// Steps with exactly one note.
    let singleVoiceStepCount: Int
    /// Steps with exactly two notes.
    let twoVoiceStepCount: Int
    /// Steps with three or more notes.
    let threeOrMoreVoiceStepCount: Int
    let uniqueMIDINotes: Int
    let uniquePitchClasses: Int

    // Distribution
    let pitchClassHistogram: [Int]            // 12 bins, sum == noteCount
    let pitchClassEntropy: Double             // bits, 0 when no notes
    let maximumPitchClassShare: Double        // 0...1

    // Intervals (extracted from the most-acute note per step).
    // The melodic policy skips rests: a transition is defined as the
    // absolute difference between consecutive most-acute notes.
    let meanIntervalSemitones: Double         // 0 when fewer than 2 active steps
    let maximumJumpSemitones: Int             // 0 when fewer than 2 active steps
    let melodicTransitionCount: Int           // number of consecutive most-acute pairs
    /// Transitions where the absolute interval is `0` (same MIDI note
    /// repeated across consecutive most-acute steps).
    let zeroIntervalTransitionCount: Int
    /// Share of melodic transitions that have interval `0`.
    /// Returns `0` when there are no melodic transitions.
    let zeroIntervalTransitionShare: Double

    // Rhythm and density.
    // `noteDensity = noteCount / PedalSequence.maximumNoteSlots`, where
    // `maximumNoteSlots = PedalSequence.steps * PedalSequence.rows`
    // represents the structural upper bound of simultaneous notes
    // a v1 sequence can carry.
    let durationHistogram: [String: Int]      // velocity buckets
    let noteDensity: Double
    let restDensity: Double                   // restStepCount / PedalSequence.steps
    let multiNoteStepShare: Double            // (twoVoice + threeOrMore) / max(1, activeStepCount)

    // Performance
    let sequenceGenerationDurationMilliseconds: Double
    let diagnosticsCalculationDurationMilliseconds: Double
    let totalRunDurationMilliseconds: Double
    /// Resident memory size before the run. `nil` when the platform
    /// sampler could not read it.
    let residentMemoryBytesBefore: UInt64?
    /// Resident memory size after the run. `nil` when the platform
    /// sampler could not read it.
    let residentMemoryBytesAfter: UInt64?
}
#endif
