import Foundation

/// Intermediate deterministic profile between the visual analysis
/// and the v2 music generator. See
/// `specs/current/photo-midi-variety-v2.md` §7.2 and
/// `specs/current/photo-midi-variety-v2-incremento-2.md` §6.3.
///
/// Increment 2 introduces the struct shape and the invariant checks
/// (verified by `MusicalProfileInvariantTests`). The builder that
/// derives a `MusicalProfile` from a `VisualAnalysis` lives in a
/// later increment. In this delivery, every `MusicalProfile` is
/// constructed by direct memberwise
/// initialization (typically in tests); `generationSeed` is always
/// `0` and `tonalFamily` is always `.neutral` as placeholders.
///
/// `MusicalProfile` is **not persisted**; the type is `Sendable` and
/// `Equatable` but not `Codable`.
struct MusicalProfile: Sendable, Equatable {
    let rootPitchClass: PitchClass
    let scale: PedalScale
    /// Semitones above C0. Lower bound `>= 0`, upper bound `<= 96`,
    /// and the range must span at least one octave.
    let register: ClosedRange<Int>
    /// Target share of steps that contain a note. In `[0.10, 0.95]`.
    let density: Double
    /// In `[0, 1]`.
    let syncopation: Double
    /// Allowed semitone distance between consecutive notes. `lowerBound >= 1`,
    /// `upperBound <= 24`.
    let intervalRange: ClosedRange<Int>
    /// In `[0, 1]`.
    let repetitionFactor: Double
    /// In `[0, 1]`.
    let tension: Double
    let contour: MelodicContour
    /// In `[70, 140]`.
    let bpm: Int
    /// `4` or `5`.
    let baseOctave: Int
    /// Fixed at `16` in Increment 2.
    let timeSignatureSteps: Int
    /// Placeholder. In Increment 2, always `0`. A later increment
    /// replaces this with the deterministic value derived from the
    /// `fingerprint`.
    let generationSeed: UInt64
    /// Placeholder. In Increment 2, always `.neutral`.
    let tonalFamily: TonalFamily
}

extension MusicalProfile {
    /// Validate the invariants declared in
    /// `specs/current/photo-midi-variety-v2-incremento-2.md` §6.3.
    /// Throws an error describing the first violation encountered.
    func validate() throws {
        guard (0 ... 11).contains(rootPitchClass.rawValue) else { throw VisualAnalysisError.invariantViolation("rootPitchClass.rawValue out of range: \(rootPitchClass.rawValue)") }
        guard register.lowerBound >= 0 else { throw VisualAnalysisError.invariantViolation("register.lowerBound < 0: \(register.lowerBound)") }
        guard register.upperBound <= 96 else { throw VisualAnalysisError.invariantViolation("register.upperBound > 96: \(register.upperBound)") }
        guard register.upperBound - register.lowerBound >= 12 else { throw VisualAnalysisError.invariantViolation("register spans less than one octave: \(register)") }
        guard (0.10 ... 0.95).contains(density) else { throw VisualAnalysisError.invariantViolation("density outside [0.10, 0.95]: \(density)") }
        guard (0.0 ... 1.0).contains(syncopation) else { throw VisualAnalysisError.invariantViolation("syncopation outside [0, 1]: \(syncopation)") }
        guard (0.0 ... 1.0).contains(tension) else { throw VisualAnalysisError.invariantViolation("tension outside [0, 1]: \(tension)") }
        guard (0.0 ... 1.0).contains(repetitionFactor) else { throw VisualAnalysisError.invariantViolation("repetitionFactor outside [0, 1]: \(repetitionFactor)") }
        guard intervalRange.lowerBound >= 1 else { throw VisualAnalysisError.invariantViolation("intervalRange.lowerBound < 1: \(intervalRange.lowerBound)") }
        guard intervalRange.upperBound <= 24 else { throw VisualAnalysisError.invariantViolation("intervalRange.upperBound > 24: \(intervalRange.upperBound)") }
        guard (70 ... 140).contains(bpm) else { throw VisualAnalysisError.invariantViolation("bpm outside [70, 140]: \(bpm)") }
        guard baseOctave == 4 || baseOctave == 5 else { throw VisualAnalysisError.invariantViolation("baseOctave not 4 or 5: \(baseOctave)") }
        guard timeSignatureSteps == 16 else { throw VisualAnalysisError.invariantViolation("timeSignatureSteps not 16: \(timeSignatureSteps)") }
    }
}

enum VisualAnalysisError: Error, Equatable {
    case invariantViolation(String)
}
